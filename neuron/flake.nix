{
  description = "Neuron instance with nginx";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.05";
    nixops.url = "github:NixOS/nixops";
    utils.url = "github:numtide/flake-utils";
    neuron.url = "github:srid/neuron";
  };

  outputs = { self, nixpkgs, nixops, neuron, utils, ... }:
  {

    overlay = final: prev: {
        neuron-notes = neuron.packages.x86_64-linux.neuron;
    };

    nixopsConfigurations.default =
      {
        inherit nixpkgs;

        network.description = "Neuron";
        neuron = { config, pkgs, ... }:
        import ./neuron.nix { inherit config pkgs; }
        // { nixpkgs.overlays = [ self.overlay ]; }
        ;
      };
    };

}
