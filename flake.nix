{
  description = "Nix configurations ready for deployment";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.05";
    nixops.url = "github:NixOS/nixops";
    utils.url = "github:numtide/flake-utils";
    neuron.url = "github:srid/neuron";
    myDrvs.url = "github:huuff/derivations";
  };

  outputs = { self, nixpkgs, nixops, neuron, utils, myDrvs, ... }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
  in
  {

    nixosModules.neuron = import ./neuron {
      doOnRequest = myDrvs.nixosModules.doOnRequest;
      neuronPkg = neuron.packages.x86_64-linux.neuron;
    };
    nixosModules.osticket = import ./osticket;
    nixosTests.neuron = import ./neuron/test.nix {
      doOnRequest = myDrvs.nixosModules.doOnRequest;
      neuronPkg = neuron.packages.x86_64-linux.neuron;
      inherit pkgs;
    };
  };

}
