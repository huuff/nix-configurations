{ config, pkgs, lib, ... }:
{
  imports = [
    (import ./default.nix { myLib = import ../../lib { inherit lib; }; })
  ];

  virtualisation.memorySize = "2048M";

  services.wallabag = {
    enable = true;
  };
}
