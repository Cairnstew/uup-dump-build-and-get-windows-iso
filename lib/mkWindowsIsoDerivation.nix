{ pkgs, lib }:

{ tag, parts, isoName, isoHash ? null }:

let
  inherit (builtins) length concatStringsSep map toString foldl';
  inherit (lib) hasPrefix removePrefix optionalAttrs optionalString strings;

  partSrcs = map (part: pkgs.fetchurl ({
    url = part.url;
  } // (if part ? sha256 then { inherit (part) sha256; } else { sha256 = lib.fakeSha256; }))) parts;

  totalBytes = foldl' (acc: p: acc + (p.size or 0)) 0 parts;

  fixedOutput = optionalAttrs (isoHash != null) {
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = removePrefix "sha256-" isoHash;
  };
in
assert length parts > 0;
assert isoHash == null || hasPrefix "sha256-" isoHash;

pkgs.stdenv.mkDerivation ({
  name = strings.sanitizeDerivationName isoName;

  nativeBuildInputs = with pkgs; [ p7zip ];

  buildCommand = ''
    echo "Release: ${tag}"
    echo "Parts:   ${toString (length parts)} x zip parts"
    echo "Total:   $(${pkgs.coreutils}/bin/numfmt --to=iec ${toString totalBytes})"
    echo "ISO:     ${isoName}"
    echo ""

    # Copy all parts to a single directory so 7z can find them
    mkdir -p "$TMPDIR/parts"
    i=1
    ${concatStringsSep "\n" (map (p: ''
      echo "  [$i/${toString (length parts)}] Copying $(basename '${p}')..."
      cp '${p}' "$TMPDIR/parts/"
      i=$((i + 1))
    '') partSrcs)}

    echo ""
    echo "Extracting ISO with 7-Zip..."
    set -- "$TMPDIR/parts"/*.zip.001
    first_part="$1"
    7z x "$first_part" -o"$TMPDIR/extracted" -y -bsp1 -bso0 2>&1 || \
    7z x "$first_part" -o"$TMPDIR/extracted" -y -bsp0 -bso0

    for f in "$TMPDIR/extracted"/*.ISO "$TMPDIR/extracted"/*.iso; do
      [ -f "$f" ] || continue
      iso_file="$f"
      break
    done
    if [ -z "$iso_file" ]; then
      echo "ERROR: No ISO file found in extracted archive" >&2
      exit 1
    fi

    ${optionalString (isoHash != null) ''
      echo "Verifying ISO hash..."
      actual=$(sha256sum "$iso_file" | cut -d' ' -f1)
      expected=${removePrefix "sha256-" isoHash}
      if [ "$actual" != "$expected" ]; then
        echo "ISO hash mismatch!" >&2
        echo "  expected: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
      fi
    ''}

    cp "$iso_file" "$out"

    echo ""
    echo "Done: $(basename "$iso_file") ($(du -h "$out" | cut -f1))"
  '';
} // fixedOutput)
