{ config, lib, pkgs, ... }:
let
  cfg = config.my.iso.windows;
  mkWindowsIso = pkgs.callPackage ../../lib/mkWindowsIsoDerivation.nix { };
in
{
  config = lib.mkIf cfg.enable {
    my.iso.windows.package = mkWindowsIso {
      tag = cfg.release.tag;
      parts = cfg.release.parts;
      isoName = cfg.release.isoName;
      isoHash = cfg.release.isoHash;
    };
  };
}
