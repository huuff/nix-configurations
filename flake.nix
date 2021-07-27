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
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    doOnRequest = myDrvs.nixosModules.doOnRequest;
    neuronPkg = neuron.packages.${system}.neuron;
  in
  {
    nixosModules = {
      neuron = import ./neuron { inherit doOnRequest neuronPkg; };
      osticket = import ./osticket;
    };

    nixosTests = {
      neuron = import ./neuron/test.nix { inherit pkgs doOnRequest neuronPkg; };
      osticket = import ./osticket/test.nix { inherit pkgs; };
    };
  };

}
