{ config, pkgs, ... }:
let
  osTicket = pkgs.callPackage ./osticket-derivation.nix { };
in
{
  environment.systemPackages = [
    osTicket
  ];

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = pkgs.writeText "initScript" ''
      CREATE DATABASE osticket;
      CREATE USER 'osticket'@'localhost';
      GRANT ALL PRIVILEGES ON osticket.* TO 'osticket'@'localhost' IDENTIFIED BY 'password';
      '';
  };
}
