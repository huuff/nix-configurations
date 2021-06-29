{
  description = "Neuron instance with nginx";

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

    nixopsConfigurations.default =
      {
        inherit nixpkgs;

        network.description = "Neuron";
        neuron = { config, pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];
          imports = [
            ./neuron.nix
            mydrvs.nixosModules.x86_64-linux.auto-rsync
          ];
        };
      };
    };

  }
