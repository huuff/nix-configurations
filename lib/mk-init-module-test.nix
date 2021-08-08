{ pkgs, ... }:
let
  testFilePath = "/var/testfile";
in
pkgs.nixosTest {
  name = "mk-init-module";

  machine = { pkgs, ... }: {
    imports = [ (import ./mk-init-module.nix "test") ];

    system.activationScripts.createTestFile.text = "touch ${testFilePath}";

    services.test.initialization = [
      {
        name = "unit1";
        description = "First unit";
        script = "echo -n 'unit1 ' >> ${testFilePath}";
      }
      {
        name = "unit2";
        description = "Second unit";
        script = "echo -n 'unit2 ' >> ${testFilePath}";
      }
      {
        name = "unit3";
        description = "Third unit";
        script = "echo -n 'unit3' >> ${testFilePath}";
      }
    ];
  };

  testScript = ''
    ${ builtins.readFile ./testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("units are active"):
      machine.succeed("systemctl is-active --quiet unit1")
      machine.succeed("systemctl is-active --quiet unit2")

    # This tests that the echos have been done in the correct ordered
    # and thus, that the units are correctly ordered
    with subtest("units are correctly ordered"):
      outputs(machine, "cat ${testFilePath}", "unit1 unit2 unit3")

    with subtest("units are not started on restart"):
      machine.shutdown()
      machine.start()
      machine.fail("systemctl is-active --quiet unit1")
      machine.fail("systemctl is-active --quiet unit2")
  '';
}
