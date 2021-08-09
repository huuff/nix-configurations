{
  description = "Nix configurations ready for deployment";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.05";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {
    nixosModules = {
      neuron = import ./machines/neuron;
      osticket = import ./machines/osticket;
    };

    checks.${system} = {
      neuron = import ./machines/neuron/test.nix { inherit pkgs; };
      wallabag = import ./machines/wallabag/test.nix { inherit pkgs; };
      osticket = import ./machines/osticket/test.nix { inherit pkgs; };

      ensurePaths = import ./lib/ensure-paths-test.nix { inherit pkgs; };
      doOnRequest = import ./lib/do-on-request-test.nix { inherit pkgs; };

      mkSSLModule = import ./lib/mk-ssl-module-test.nix { inherit pkgs; };
      mkInstallationModule = import ./lib/mk-installation-module-test.nix { inherit pkgs; };
      mkDatabaseModule = import ./lib/mk-database-module-test.nix { inherit pkgs; };
      mkInitModule = import ./lib/mk-init-module-test.nix { inherit pkgs; };
    };
  };

}
