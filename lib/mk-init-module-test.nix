{ pkgs, ... }:
pkgs.nixosTest {
  name = "mk-init-module";

  machine = { pkgs, ... }: {
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
  };

  testScript = ''
    ${ builtins.readFile ./testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("units are active"):
      machine.succeed("systemctl is-active --quiet unit1")
      machine.succeed("systemctl is-active --quiet unit2")

    with subtest("units are not started on restart"):
      machine.shutdown()
      machine.start()
      machine.fail("systemctl is-active --quiet unit1")
      machine.fail("systemctl is-active --quiet unit2")
  '';
}
