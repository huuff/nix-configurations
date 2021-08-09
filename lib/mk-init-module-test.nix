{ pkgs, ... }:
let
  lib = pkgs.lib;
  testFilePath = "/var/testfile";
in
  pkgs.nixosTest {
    name = "mk-init-module";

    nodes = rec {
      machine = { pkgs, ... }: {
        imports = [ (import ./mk-init-module.nix "test") ];

        system.activationScripts.createTestFile.text = "touch ${testFilePath}";

        services.test.initialization = [
          {
            name = "unit1";
            description = "First unit";
            path = [ pkgs.hello ];
            script = "hello -v && echo -n 'unit1 ' >> ${testFilePath}";
          }
          {
            name = "unit2";
            description = "Second unit";
            extraDeps = [ "test-service.service" ];
            script = "echo -n 'unit2 ' >> ${testFilePath}";
          }
          {
            name = "unit3";
            description = "Third unit";
            script = "echo -n 'unit3' >> ${testFilePath}";
          }
        ];

        systemd.services.test-service = {
          description = "Service to test extraDeps";
          script = "echo test";

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      };

  # Same as machine, but test-service fails so unit2 should fail
  machineWithoutTestService = {pkgs, ... }:
  lib.recursiveUpdate (machine { inherit pkgs;}) {
    systemd.services.test-service.script = "exit 1";
  };
};

testScript = ''
    ${ builtins.readFile ./testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("units are active"):
      machine.succeed("systemctl is-active --quiet unit1")
      machine.succeed("systemctl is-active --quiet unit2")
      machine.succeed("systemctl is-active --quiet unit3")
      machine.succeed("systemctl is-active --quiet test-service")

    # This tests that the echos have been done in the correct ordered
    # and thus, that the units are correctly ordered
    with subtest("units are correctly ordered"):
      machine.outputs("cat ${testFilePath}", "unit1 unit2 unit3")

    with subtest("unit fails if extraDeps fail"):
     machineWithoutTestService.wait_for_unit("multi-user.target")
     machineWithoutTestService.fail("systemctl is-active --quiet unit2") 

    with subtest("units are not started on restart"):
      machine.shutdown()
      machine.start()
      machine.fail("systemctl is-active --quiet unit1")
      machine.fail("systemctl is-active --quiet unit2")
      machine.fail("systemctl is-active --quiet unit3")
'';
}
