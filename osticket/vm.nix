# Environment for nixos-shell, for testing purposes
{ config, pkgs, lib, ... }:
{
  imports = [
    ./osticket.nix 
  ];

  networking.firewall.allowedTCPPorts = [ 3306 ];

  services.osticket = {
    enable = true;

    admin = {
      username = "root";
      #password = "passwd";
      email = "root@example.com";
      firstName = "Firstname";
      lastName = "Lastname";
    };

    database = {
      name = "osticket";
      user = "osticket";
      # This goes to the Nix store so obviously something better would be needed in
      # production. But this is just for testing
      passwordFile = pkgs.writeText "dbpass" (builtins.readFile ./dbpass);
    };

    site = {
      name = "osTicket";
      email = "site@example.com";
    };
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
