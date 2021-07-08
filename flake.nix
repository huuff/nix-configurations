{
  description = "Nix configurations ready for deployment";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.05";
    nixops.url = "github:NixOS/nixops";
    utils.url = "github:numtide/flake-utils";
    neuron.url = "github:srid/neuron";
    mydrvs.url = "github:huuff/derivations";
  };

  outputs = { self, nixpkgs, nixops, neuron, utils, mydrvs, ... }:
  {

    overlay = final: prev: {
      neuron-notes = neuron.packages.x86_64-linux.neuron;
    };

    nixosConfigurations.neuron = { config, pkgs, repo, keyPath, ... }:
    {
      nixpkgs.overlays = [ self.overlay ];
      imports = [
        (import ./neuron/neuron.nix { inherit config pkgs repo keyPath; })
        ./neuron/cachix.nix
        mydrvs.nixosModules.do-on-request 
        mydrvs.nixosModules.neuron-module
      ];
    };
  };

}
