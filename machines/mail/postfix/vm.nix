{ config, pkgs, lib, ... }:
{
  imports = [
    ./default.nix
    ../../../lib/nixos-shell-base.nix
  ];

  environment.systemPackages = with pkgs; [ mailutils ];

  nixos-shell.mounts = {
    mountHome = false;
  };

  machines.postfix = {
    enable = true;
    restrictions = "rfc_conformant";
  };

  users.users = {
    alice = {
      password = "password";
      isNormalUser = true;
    };
    bob = {
      password = "password";
      isNormalUser = true;
    };
  };
}
