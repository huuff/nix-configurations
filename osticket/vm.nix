# Environment for nixos-shell, for testing purposes
{ config, pkgs, lib, ... }:
{
  imports = [
    ./osticket.nix 
  ];

  services.osticket = {
    enable = true;

    admin = {
      username = "root";
      password = "passwd";
      email = "root@example.com";
      firstName = "Firstname";
      lastName = "Lastname";
    };

    database = {
      name = "osticket";
      user = "osticket";
      password = "password";
    };

    site = {
      name = "osTicket";
      email = "site@example.com";
    };
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8989-:80"
  ];
}
