{ config, pkgs, ... }:
{
  imports = [
    ./neuron-module.nix
    ./cachix.nix
  ];

  services.neuron = {
    enable = true;
    path = "/home/neuron/";
  };

  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 ];
  };

  deployment = {
    targetEnv = "virtualbox";
    virtualbox = {
      memorySize = 1024;
      vcpu = 2;
      headless = true;
    };
  };
}
