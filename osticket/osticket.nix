{ config, pkgs, ... }:
{


  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    user = "root";
    initialScript = /home/haf/nix-machines/osticket/initalScript.sql;
  };
}
