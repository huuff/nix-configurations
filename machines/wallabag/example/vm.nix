{ config, pkgs, lib, ... }:
{
  imports = [
    ../default.nix
  ];

  virtualisation.memorySize = "2048M";

  services.wallabag = {
    enable = true;

    database.passwordFile = ./dbpass;
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8987-:80"
  ];
}
