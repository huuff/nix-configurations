{ config, pkgs, lib, ... }:
{
  imports = [
    ../default.nix
  ];

  virtualisation.memorySize = "2048M";

  services.wallabag = {
    enable = true;
    ssl.enable = true;

    database.passwordFile = ./dbpass;

    users = [
      {
        username = "user1";
        passwordFile = ./user1pass;
        email = "user1@example.com";
      }
    ];
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8987-:80,hostfwd=tcp::8986-:443"
  ];
}
