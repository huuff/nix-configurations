{ config, pkgs, ... }:
{


  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = pkgs.writeText "initScript" ''
      CREATE DATABASE osticket;
      CREATE USER 'osticket'@'localhost';
      GRANT ALL PRIVILEGES ON osticket.* TO 'osticket'@'localhost' IDENTIFIED BY 'password';
      '';
      #GRANT ALL PRIVILEGES ON osticket.* TO 'osticket';
  };
}
