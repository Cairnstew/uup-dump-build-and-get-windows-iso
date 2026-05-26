{
  description = "Windows ISO builder from UUP dump GitHub releases";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      inherit (builtins) fromJSON readFile fetchurl tryEval pathExists filter
                       match head length sort listToAttrs map;

      inherit (nixpkgs.lib) genAttrs nameValuePair hasPrefix removePrefix;

      repoOwner = "Cairnstew";
      repoName = "uup-dump-build-and-get-windows-iso";
      repo = "${repoOwner}/${repoName}";
      apiURL = "https://api.github.com/repos/${repo}/releases";

      systems = [ "x86_64-linux" "aarch64-linux" ];

      # GitHub digest "sha256:hex" -> bare hex for pkgs.fetchurl sha256
      toHex = d:
        if d == "" then ""
        else if hasPrefix "sha256:" d then removePrefix "sha256:" d
        else d;

      # Extract ISO name from "file.ISO.zip.001" -> "file.ISO"
      isoNameFromAsset = name:
        let m = match "(.*)[.]zip[.][0-9]+" name;
        in if m == null then null else head m;

      isZipPart = name: match ".*[.]zip[.][0-9]+" name != null;

      assetUrl = a: a.browser_download_url or a.url or "";
      assetDigest = a: a.digest or "";

      releaseTag = rel: rel.tagName or rel.tag_name or "";
      releaseAssets = rel: rel.assets or [];

      # Convert a release JSON object into a processed record
      processRelease = rel:
        let
          tag = releaseTag rel;
          allAssets = releaseAssets rel;
          zipAssets = sort (a: b: (assetUrl a) < (assetUrl b))
            (filter (a: isZipPart (a.name or "")) allAssets);
          parts = map (a:
            let
              hex = toHex (assetDigest a);
            in
            {
              url = assetUrl a;
              size = a.size or 0;
            } // (if hex != "" then { sha256 = hex; } else { })) zipAssets;
          firstPartName = if zipAssets != [] then (head zipAssets).name or "" else "";
          isoName = if firstPartName != "" then isoNameFromAsset firstPartName else null;
        in {
          inherit tag parts isoName;
          valid = parts != [] && isoName != null;
        };

      # In pure eval mode, reads the committed releases.lock file.
      # With --impure, fetches the live GitHub API when no lockfile exists.
      releasesData =
        if pathExists ./releases.lock then
          (tryEval (fromJSON (readFile ./releases.lock))).value or [ ]
        else
          let api = tryEval (fromJSON (readFile (fetchurl { url = apiURL; })));
          in if api.success then api.value else [ ];

      processedReleases = map processRelease releasesData;
      validReleases = filter (r: r.valid) processedReleases;

      forAllSystems = genAttrs systems;
    mkPkgsForSystem = system:
      let
        pkgs = import nixpkgs { inherit system; };
        mkWindowsIso = pkgs.callPackage ./lib/mkWindowsIsoDerivation.nix { };

        buildPkg = r:
          nameValuePair "windows-iso-${r.tag}" (mkWindowsIso {
            tag = r.tag;
            parts = r.parts;
            isoName = r.isoName;
          });

        perReleasePackages = listToAttrs (map buildPkg validReleases);

        defaultPkg =
          if validReleases != [] then
            let
              latest = head validReleases;
            in
            mkWindowsIso {
              tag = latest.tag;
              parts = latest.parts;
              isoName = latest.isoName;
            }
          else
            pkgs.runCommand "no-releases" { } ''
              echo "ERROR: No Windows ISO releases found." >&2
              echo "" >&2
              echo "Run with '--impure' to fetch from the GitHub API," >&2
              echo "or run 'lib/update-releases.sh' to generate a releases.lock." >&2
              exit 1
            '';
      in
      perReleasePackages // { default = defaultPkg; };

    mkAppsForSystem = system:
      let
        pkgs = import nixpkgs { inherit system; };

        buildScript = pkgs.writeShellApplication {
          name = "get-windows-iso";
          runtimeInputs = with pkgs; [ curl jq p7zip ];
          text = ''
            set -euo pipefail

            REPO="${repo}"
            TMPDIR="$(mktemp -d)"
            trap 'rm -rf "$TMPDIR"' EXIT

            # ── Fetch release metadata ──────────────────────────────
            echo ":: Fetching release info from GitHub..."
            curl -sfL "https://api.github.com/repos/$REPO/releases" > "$TMPDIR/releases.json"

            LATEST_TAG=$(jq -r '[.[] | select(.assets // [] | map(.name) | map(select(test("[.]zip[.][0-9]+$"))) | length > 0)] | first | .tag_name // empty' "$TMPDIR/releases.json")
            if [ -z "$LATEST_TAG" ]; then
              echo "ERROR: No releases with ISO zip parts found" >&2
              exit 1
            fi

            # ── Extract asset info ──────────────────────────────────
            ASSETS_JSON=$(jq -c ".[] | select(.tag_name == \"$LATEST_TAG\") | .assets[] | select(.name | test(\"[.]zip[.][0-9]+$\"))" "$TMPDIR/releases.json" | sort)

            TOTAL_PARTS=$(echo "$ASSETS_JSON" | jq -s 'length')
            TOTAL_BYTES=$(echo "$ASSETS_JSON" | jq -s '[.[].size] | add // 0')

            echo ""
            echo "Release:  $LATEST_TAG"
            echo "Parts:    $TOTAL_PARTS x split-zip"
            echo "Download: $(numfmt --to=iec "$TOTAL_BYTES") ($TOTAL_BYTES bytes)"
            echo ""

            # ── Download parts with cumulative progress ─────────────
            DL_BYTES=0
            i=1
            echo "$ASSETS_JSON" | jq -c '.' | while read -r asset; do
              NAME=$(echo "$asset" | jq -r '.name')
              URL=$(echo "$asset" | jq -r '(.browser_download_url // .url)')
              SIZE=$(echo "$asset" | jq -r '.size // 0')

              echo "[$i/$TOTAL_PARTS] $NAME"
              curl -# --fail -L -o "$TMPDIR/part_$(printf '%03d' $i)" "$URL"

              DL_BYTES=$((DL_BYTES + SIZE))
              PCT=$(echo "scale=1; $DL_BYTES * 100 / $TOTAL_BYTES" | bc 2>/dev/null || echo "?")
              echo "  Overall: $(numfmt --to=iec "$DL_BYTES") / $(numfmt --to=iec "$TOTAL_BYTES") (''${PCT}%)"
              echo ""
              i=$((i + 1))
            done

            # ── Extract ISO ─────────────────────────────────────────
            echo ":: Extracting ISO with 7-Zip..."
            set -- "$TMPDIR"/part_*
            first_part="$1"
            7z x "$first_part" -o"$TMPDIR/extracted" -y -bsp1 2>&1 || \
            7z x "$first_part" -o"$TMPDIR/extracted" -y -bsp0

            for f in "$TMPDIR/extracted"/*.ISO "$TMPDIR/extracted"/*.iso; do
              [ -f "$f" ] || continue
              ISO="$f"
              break
            done
            if [ -z "$ISO" ]; then
              echo "ERROR: No ISO file found in extracted archive" >&2
              exit 1
            fi

            ISO_SIZE=$(du -h "$ISO" | cut -f1)
            ISO_HASH=$(sha256sum "$ISO" | cut -d' ' -f1)

            echo ""
            echo "━━━ ISO ready ━━━"
            echo " File:   $(basename "$ISO")"
            echo " Size:   $ISO_SIZE"
            echo " SHA256: $ISO_HASH"
            echo ""

            DEST="$(pwd)/$(basename "$ISO")"
            cp "$ISO" "$DEST"
            echo "Saved to: $DEST"
          '';
        };
      in
      {
        default = {
          type = "app";
          program = "${buildScript}/bin/get-windows-iso";
        };
      };
  in
  {
    packages = forAllSystems mkPkgsForSystem;
    apps = forAllSystems mkAppsForSystem;
  };
}
