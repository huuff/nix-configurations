{
  description = "Set of pre-baked NixOS configurations for my specific purposes";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.05";
    nixops.url = "github:NixOS/nixops";
    neuron.url = "github:srid/neuron";
    mydrvs.url = "github:huuff/derivations";
  };

  outputs = { self, nixpkgs, nixops, neuron, mydrvs, ... }:
  {

    nixopsConfigurations.neuron = { repo, keyPath }: 
    {
      inherit nixpkgs;


      overlay = final: prev: {
        neuron-notes = neuron.packages.x86_64-linux.neuron;
      };

      network.description = "Neuron";
      neuron = { config, pkgs, ... }:
      {
        nixpkgs.overlays = [ self.overlay ];
        imports = [
          (import ./neuron/neuron.nix { inherit config pkgs repo; })
          ./neuron/cachix.nix
          mydrvs.nixosModules.x86_64-linux.auto-rsync
          mydrvs.nixosModules.x86_64-linux.do-on-request 
          mydrvs.nixosModules.x86_64-linux.neuron-module
        ];

        deployment = {
          targetEnv = "libvirtd";
          libvirtd.headless = true;
          keys.deploy.keyFile = keyPath;
        };

      };
    };
  };
}
