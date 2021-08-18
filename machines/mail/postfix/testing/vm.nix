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
    restrictions = "rfc_conformant";
    canonicalDomain = "example.com";

    main = {
      smtp_host_lookup = "native";
    };

    users = [
      "user1@example.com"
      "user2@example.com"
    ];
  };

  networking.extraHosts = "google.com test.org";
}
