# Environment for nixos-shell, for testing purposes
{ config, pkgs, lib, ... }:

let
  # This goes to the store, so obviously something better would be needed in production
  fileFromStore = file: pkgs.writeText "${file}" (builtins.readFile file);
in {
  imports = [
    ../default.nix
  ];

  networking.firewall.allowedTCPPorts = [ 3306 ];

  services.osticket = {
    enable = true;

    ssl = {
      enable = true;
      certificate = ./cert.pem;
      key = ./key.pem;
    };

    admin = {
      username = "root";
      passwordFile = fileFromStore ./adminpass;
      email = "root@example.com";
      firstName = "Firstname";
      lastName = "Lastname";
    };

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

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };

  users = {
    users.root.password="pass";
    mutableUsers=false;
  };
}