{ config, pkgs, lib, ... }:
let
  myLib = import ../../../lib { inherit config pkgs; };
in
{
  imports = [
    ../default.nix
  ];

  virtualisation.memorySize = "2048M";

  services.wallabag = {
    enable = true;
    #ssl.enable = true;

    domainName = "http://188.85.208.67";

    database.passwordFile = myLib.fileFromStore ./dbpass;

    users = [
      {
        username = "user1";
        passwordFile = myLib.fileFromStore ./user1pass;
        email = "user1@example.com";
      }
    ];
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8987-:80,hostfwd=tcp::8986-:443"
  ];
}
