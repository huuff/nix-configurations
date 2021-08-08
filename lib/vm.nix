{ pkgs, ... }: {
    imports = [ (import ./mk-init-module.nix "test") ];

    services.test.initialization = [
      {
        name = "unit1";
        description = "First unit";
        script = "echo test1";
      }
      {
        name = "unit2";
        description = "Second unit";
        script = "echo test2";
      }
    ];
  }

