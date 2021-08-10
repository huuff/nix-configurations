{ config, pkgs, lib, ... }:
{
  imports = [ ./postfix.nix ];

  environment.systemPackages = with pkgs; [
    mailutils
    lsof
    telnet
  ];

  machines.postfix = {
    enable = true;
  };
}
