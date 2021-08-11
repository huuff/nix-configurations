{ config, pkgs, lib, ... }:
let
  myLib = import ../../../lib { inherit config pkgs; };
in with myLib; {
  imports = [
    ../default.nix
    ../../../lib/nixos-shell-base.nix
  ];

  virtualisation.memorySize = "2048M";

  environment.systemPackages = with pkgs; [
    php74
    php74Packages.composer
  ];

  machines.wallabag = {
    enable = true;
    domainName = "https://localhost:8988";
    ssl.enable = true;

    database.passwordFile = fileFromStore ./dbpass;
    enableRedis = true;

    users = [
      {
        username = "user1";
        passwordFile = fileFromStore ./user1pass;
        email = "user1@example.com";
        pocketKeyFile = fileFromStore ~/pocket-key;
        superAdmin = true;
      }
    ];
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8989-:80,hostfwd=tcp::8988-:443"
  ];
}
