{ config, pkgs, ... }:
{
  imports = [
    ./neuron-module.nix
    ./cachix.nix
  ];

  services.neuron = {
    enable = true;
    path = "/home/neuron";
  };

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 ];
  };

  deployment = {
    targetEnv = "libvirtd";
    libvirtd.headless = true;
  };
}
