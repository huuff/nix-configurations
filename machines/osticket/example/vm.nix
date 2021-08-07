{ config, pkgs, lib, ... }:

let
  myLib = import ../../../lib { inherit config pkgs; }; 
in with myLib; {
  imports = [
    ../default.nix
    ../../../lib/nixos-shell-base.nix
  ];

  networking.firewall.allowedTCPPorts = [ 3306 ];

  services.osticket = {
    enable = true;

    installation.path = "/var/www/osticket";

    admin = {
      username = "root";
      passwordFile = fileFromStore ./adminpass;
      email = "root@example.com";
      firstName = "Firstname";
      lastName = "Lastname";
    };

    ssl.enable = false;

    database.passwordFile = fileFromStore ./dbpass;

    site.email = "site@example.com";

    users = [
      {
        username = "user1";
        fullName = "Mr. User 1";
        email = "user1@example.com";
        passwordFile = fileFromStore ./user1pass;
      }

      {
        username = "user2";
        fullName = "Ms. User 2";
        email = "user2@example.com";
        passwordFile = fileFromStore ./user2pass;
      }
    ];
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8989-:80,hostfwd=tcp::2222-:22,hostfwd=tcp::8988-:443"
  ];
}
