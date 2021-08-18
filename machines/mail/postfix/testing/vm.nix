{ config, pkgs, lib, ... }:
{
  imports = [
    ../default.nix
    ../../../../lib/nixos-shell-base.nix
  ];

  environment.systemPackages = with pkgs; [
    mailutils 
    mutt
  ];

  machines.postfix = {
    enable = true;
    canonicalDomain = "example.com";

    users = [
      "user1@example.com"
      "user2@example.com"
    ];
  };

}
