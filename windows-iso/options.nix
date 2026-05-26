{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.iso.windows = {
    enable = mkEnableOption "Windows ISO derivation from UUP dump split archives";

    release = mkOption {
      type = types.submodule {
        options = {
          tag = mkOption {
            type = types.str;
            example = "22631.7079.23H2.PRO.X64.EN";
            description = "Release tag in <build>.<revision>.<channel>.<edition>.<arch>.<lang> format.";
          };

          parts = mkOption {
            type = types.listOf (types.submodule {
              options = {
                url = mkOption {
                  type = types.str;
                  example = "https://github.com/example/windows-iso/releases/download/22631.7079.23H2.PRO.X64.EN/windows.iso.zip.001";
                  description = "URL of this split archive part.";
                };
                sha256 = mkOption {
                  type = types.str;
                  example = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                  description = "SRI hash of this split archive part.";
                };
              };
            });
            description = "List of split archive parts (.zip.001, .zip.002, ...) for this release.";
          };

          isoName = mkOption {
            type = types.str;
            example = "22631.7079.23H2.PRO.X64.EN.iso";
            description = "Filename of the reassembled ISO.";
          };

          isoHash = mkOption {
            type = types.str;
            example = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
            description = "SRI hash of the reassembled ISO (sha256-...).";
          };
        };
      };
      description = "Release metadata for the Windows ISO.";
    };

    package = mkOption {
      type = types.package;
      readOnly = true;
      description = "The assembled Windows ISO derivation.";
    };
  };
}
