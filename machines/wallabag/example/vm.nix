{ config, pkgs, lib, ... }:
let
  myLib = import ../../../lib { inherit config pkgs; };
in with myLib; {
  imports = [
    ../default.nix
    ../../../lib/nixos-shell-base.nix
  ];

  virtualisation.memorySize = "2048M";

  services.wallabag = {
    enable = true;
    ssl.enable = false;

    database.passwordFile = fileFromStore ./dbpass;

    users = [
      {
        username = "user1";
        passwordFile = fileFromStore ./user1pass;
        email = "user1@example.com";
      }
    ];
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8989-:80,hostfwd=tcp::8988-:443"
  ];
}
