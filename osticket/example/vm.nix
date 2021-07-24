# Environment for nixos-shell, for testing purposes
{ config, pkgs, lib, ... }:
let
  # This goes to the store, so obviously something better would be needed in production
  fileFromStore = file: pkgs.writeText "${file}" (builtins.readFile file);
in {
  imports = [
    ../osticket.nix 
  ];

  networking.firewall.allowedTCPPorts = [ 3306 ];

  services.osticket = {
    enable = true;

    admin = {
      username = "root";
      passwordFile = fileFromStore ./adminpass;
      email = "root@example.com";
      firstName = "Firstname";
      lastName = "Lastname";
    };

    database = {
      name = "osticket";
      user = "osticket";
      # This goes to the Nix store so obviously something better would be needed in
      # production. But this is just for testing
      passwordFile = fileFromStore ./dbpass;
    };

    site = {
      name = "osTicket";
      email = "site@example.com";
    };

    users = [
      {
        fullName = "Mr. User 1";
        email = "user1@example.com";
        passwordFile = fileFromStore ./user1pass;
      }
    ];
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8989-:80,hostfwd=tcp::2222-:22"
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
