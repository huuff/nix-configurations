{
  description = "Nix configurations ready for deployment";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.05";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    testingLib = builtins.readFile ./lib/testing-lib.py;
    importTest = test: import test { inherit pkgs testingLib; };
  in
  {
    nixosModules = {
      neuron = import ./machines/neuron;
      osticket = import ./machines/osticket;
      wallabag = import ./machines/wallabag;
      mail = import ./machines/mail;

      sshd = import ./modules/paranoid-sshd;
    };

    checks.${system} = {
      multiDeploy = importTest ./test/multi-deploy.nix;

      neuron = importTest ./machines/neuron/test.nix;
      wallabag = importTest ./machines/wallabag/test.nix;
      osticket = importTest ./machines/osticket/test.nix;

      postfixVirtual = importTest ./machines/mail/postfix/testing/virtual-test.nix;
      postfixDelivery = importTest ./machines/mail/postfix/testing/delivery-test.nix;
      postfixRestrictions = importTest ./machines/mail/postfix/testing/restrictions-test.nix;

      doOnRequest = importTest ./modules/do-on-request/test.nix;
      autoRsync = importTest ./modules/auto-rsync/test.nix;

      mkSSLModule = importTest ./modules/ssl/test.nix;
      mkInstallationModule = importTest ./lib/mk-installation-module-test.nix;
      mkDatabaseModule = importTest ./lib/mk-database-module-test.nix;
      mkInitModule = importTest ./lib/mk-init-module-test.nix;
      mkBackupModuleDatabase = importTest ./modules/backup/database-test.nix;
      mkBackupModuleDirectories = importTest ./modules/backup/directories-test.nix;
    };
  };

}
