{ config, pkgs, lib, ... }:
{
  imports = [
    ./default.nix
    ../../../lib/nixos-shell-base.nix
  ];

  machines.postfix = {
    enable = true;
  };
}
