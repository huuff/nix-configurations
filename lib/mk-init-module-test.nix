{ pkgs, testingLib, ... }:
let
  lib = pkgs.lib;
  copyMachine = import ./copy-machine.nix { inherit lib; };
  unitOrderFilePath = "/var/unit-order";
  testFilePath = "/var/test-file";
in
  pkgs.nixosTest {
    name = "mk-init-module";

    nodes = rec {
      machine1 = { pkgs, ... }: {
        imports = [ (import ./mk-init-module.nix "test") ];

        system.activationScripts.createTestFile.text = "touch ${unitOrderFilePath}";

        machines.test.initialization.units = [
          {
            name = "unit1";
            description = "First unit";
            path = [ pkgs.hello ];
            script = "hello -v && echo -n 'unit1 ' >> ${unitOrderFilePath}";
          }
          {
            name = "unit2";
            description = "Second unit";
            extraDeps = [ "test-service.service" ];
            script = "echo -n 'unit2 ' >> ${unitOrderFilePath}";
          }
          {
            name = "unit3";
            description = "Third unit";
            script = "echo -n 'unit3' >> ${unitOrderFilePath}";
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
  machine2 = copyMachine machine1 {
    systemd.services.test-service.script = "exit 1";
  };

  machine3 = copyMachine machine1 {
    systemd.services.unit2.script = "[ -e ${testFilePath} ]"; 
  };
};

testScript = ''
    ${ testingLib }

    machine1.wait_for_unit("multi-user.target")
    machine2.wait_for_unit("multi-user.target")
    machine3.wait_for_unit("multi-user.target")

    with subtest("units are active"):
      machine1.succeed("systemctl is-active --quiet unit1")
      machine1.succeed("systemctl is-active --quiet unit2")
      machine1.succeed("systemctl is-active --quiet unit3")
      machine1.succeed("systemctl is-active --quiet test-service")

    # This tests that the echos have been done in the correct ordered
    # and thus, that the units are correctly ordered
    with subtest("units are correctly ordered"):
      machine1.outputs("cat ${unitOrderFilePath}", "unit1 unit2 unit3")

    with subtest("unit fails if extraDeps fail"):
     machine2.wait_for_unit("multi-user.target")
     machine2.fail("systemctl is-active --quiet unit2") 

    with subtest("units are not started on restart"):
      machine1.shutdown()
      machine1.start()
      machine1.fail("systemctl is-active --quiet unit1")
      machine1.fail("systemctl is-active --quiet unit2")
      machine1.fail("systemctl is-active --quiet unit3")

    # In this test, the machine will fail at unit2 the first time because ${testFilePath}
    # doesn't exist. Then we create it and reset the machine and ensure that only
    # unit2 and unit3 (the remaining in the initialization process) are active
    with subtest("initialization resumes from failed unit"):
      machine3.succeed("systemctl is-active --quiet unit1")
      machine3.fail("systemctl is-active --quiet unit2")
      machine3.fail("systemctl is-active --quiet unit3")

      machine3.succeed("touch ${testFilePath}")
      machine3.shutdown()
      machine3.start()
      machine3.wait_for_unit("multi-user.target")

      machine3.fail("systemctl is-active --quiet unit1")
      machine3.succeed("systemctl is-active --quiet unit2")
      machine3.succeed("systemctl is-active --quiet unit3")
      
'';
}
