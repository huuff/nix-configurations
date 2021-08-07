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
      neuron = import ./machines/neuron { inherit doOnRequest neuronPkg; };
      osticket = import ./machines/osticket;
    };

    checks.${system} = {
      neuron = import ./machines/neuron/test.nix { inherit pkgs doOnRequest neuronPkg; };
      wallabag = import ./machines/wallabag/test.nix { inherit pkgs; };
      osticket = import ./machines/osticket/test.nix { inherit pkgs; };

      ensurePaths = import ./lib/ensure-paths-test.nix { inherit pkgs; };
      mkSSLModule = import ./lib/mk-ssl-module-test.nix { inherit pkgs; };
      mkInstallationModule = import ./lib/mk-installation-module-test.nix { inherit pkgs; };
      mkDatabaseModule = import ./lib/mk-database-module-test.nix { inherit pkgs; };
    };
  };

}
