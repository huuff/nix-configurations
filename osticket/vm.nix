# Environment for nixos-shell, for testing purposes
{ config, pkgs, lib, ... }:
let
  initialScript = pkgs.writeTextFile {
    name = "initial-script";
    text = builtins.readFile ./initial-script.sql; 
  };
in
{
  imports = [
    ./osticket.nix 
  ];

  services.osticket = {
    enable = true;
    inherit initialScript;
  };

  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8989-:80"
  ];
}
