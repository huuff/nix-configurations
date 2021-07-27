{ config, pkgs, lib, ... }:
{
  imports = [
    ./default.nix
  ];

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8080-:8080"
  ];
}
