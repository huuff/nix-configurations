{ config, pkgs, lib, ... }:
{
  imports = [
    ./default.nix
  ];

  services.wallabag = {
    enable = true;
  };
}
