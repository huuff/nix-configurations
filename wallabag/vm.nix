{ config, pkgs, lib, ... }:
{
  imports = [
    ./default.nix
  ];

  virtualisation.memorySize = "2048M";

  services.wallabag = {
    enable = true;
  };
}
