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

    overlay = final: prev: {
      neuron-notes = neuron.packages.x86_64-linux.neuron;
    };

    nixopsConfigurations.neuron = { repo, keyPath }: 
    {
      inherit nixpkgs;

      network.description = "Neuron";
      neuron = { config, pkgs, ... }:
      {
        nixpkgs.overlays = [ self.overlay ];
        imports = [
          (import ./neuron/neuron.nix { inherit config pkgs repo; })
          ./neuron/cachix.nix
          mydrvs.nixosModules.auto-rsync
          mydrvs.nixosModules.neuron-module
        ];

        deployment = {
          targetEnv = "libvirtd";
          libvirtd.headless = true;
          keys.deploy.keyFile = keyPath;
          keys.deploy.user = "neuron";
          keys.deploy.group = "neuron";
        };

      };
    };
  };
}
