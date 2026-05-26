{ pkgs, lib }:

{ tag, parts, isoName, isoHash ? null }:

let
  inherit (builtins) length concatStringsSep map elemAt genList toString;
  inherit (lib) hasPrefix removePrefix optionalAttrs optionalString strings;

  partSrcs = map (part: pkgs.fetchurl ({
    url = part.url;
  } // (if part ? sha256 then { inherit (part) sha256; } else { sha256 = lib.fakeSha256; }))) parts;

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

  nativeBuildInputs = with pkgs; [ unzip ];

  buildCommand = ''
    echo "Assembling ${isoName} from ${toString (length parts)} part(s)..."

    cat ${concatStringsSep " " (map (p: "'${p}'") partSrcs)} > "$TMPDIR/combined.zip"

    unzip -o "$TMPDIR/combined.zip" -d "$TMPDIR/extracted"

    iso_file="$(ls "$TMPDIR/extracted"/*.ISO "$TMPDIR/extracted"/*.iso 2>/dev/null | head -1)"
    if [ -z "$iso_file" ]; then
      echo "ERROR: No ISO file found in extracted archive" >&2
      exit 1
    fi

    ${optionalString (isoHash != null) ''
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

    echo "Built: $(basename "$iso_file") ($(du -h "$out" | cut -f1))"
  '';
} // fixedOutput)
