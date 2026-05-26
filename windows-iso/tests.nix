{ config, lib, ... }:
let
  cfg = config.my.iso.windows;
in
{
  assertions = [
    {
      assertion = !cfg.enable || builtins.length cfg.release.parts > 0;
      message = "my.iso.windows.release.parts must be non-empty when the module is enabled.";
    }
    {
      assertion = !cfg.enable || lib.hasPrefix "sha256-" cfg.release.isoHash;
      message = "my.iso.windows.release.isoHash must start with 'sha256-' (SRI format) when the module is enabled.";
    }
  ];
}
