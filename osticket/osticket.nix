{ config, pkgs, ... }:
{


  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = pkgs.writeText "initScript" ''
      CREATE DATABASE osticket;
      CREATE USER 'osticket' IDENTIFIED BY 'pass';
      GRANT ALL PRIVILEGES ON osticket.* TO 'osticket';
      '';
  };
}
