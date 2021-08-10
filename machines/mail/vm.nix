{ config, pkgs, lib, ... }:
{
  imports = [ ./default.nix ];

  environment.systemPackages = [
    pkgs.mailutils
  ];

  nixos-shell.mounts = {
    mountHome = false;
  };

  users.users = {
    bob.isNormalUser = true;
    alice.isNormalUser = true;
  };

  services.mail = {
    enable = true;
  };
}
