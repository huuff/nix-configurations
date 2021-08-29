{ config, pkgs, lib, ... }:

let
  myLib = import ../../../lib { inherit config pkgs lib; }; 
in with myLib; {
  imports = [
    ../default.nix
    ../../../lib/nixos-shell-base.nix
  ];

  networking.firewall.allowedTCPPorts = [ 3306 ];

  forwardedPorts = {
    "8989" = "80";
    "2222" = "22";
    "8988" = "443";
  };

  machines.osticket = {
    enable = true;

    installation.path = "/var/www/osticket";

    admin = {
      username = "root";
      passwordFile = pkgs.writeText "adminpass" "adminpass";
    };

    ssl.enable = true;
    ssl.sslOnly = false;

    database = {
      authenticationMethod = "password";
      passwordFile = pkgs.writeText "dbpass" "dbpass";
    };

    site.email = "site@example.com";

    users = [
      {
        username = "user1";
        fullName = "Mr. User 1";
        email = "user1@example.com";
        passwordFile = pkgs.writeText "user1pass" "user1pass";
      }

      {
        username = "user2";
        fullName = "Ms. User 2";
        email = "user2@example.com";
        passwordFile = pkgs.writeText "user2pass" "user2pass";
      }
    ];
  };
}
