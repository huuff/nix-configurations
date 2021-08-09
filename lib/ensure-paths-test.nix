{ pkgs, ... }:
let
  path1 = "/var/path1";
  path2 = "/var/midpath/path2";
  path3 = "/var/path3";
in
pkgs.nixosTest {
  name = "ensure-paths";

  machine = { pkgs, ... }: {
    imports = [ ./ensure-paths-module.nix ];

    services.ensurePaths = [
      { path = path1; owner = "user1"; permissions = "644"; }
      { path = path2; owner = "user2"; permissions = "755"; }
      path3 
    ];

    users.users.user1.isSystemUser = true;
    users.groups.user1 = {};
    users.users.user2.isSystemUser = true;
    users.groups.user2 = {};
  };

  testScript = ''
    ${ builtins.readFile ./testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet ensure-paths")

    with subtest("paths exist"):
      machine.succeed("[ -d ${path1} ]")
      machine.succeed("[ -d ${path2} ]")
      machine.succeed("[ -d ${path3} ]")

    with subtest("paths belong to their owners"):
      outputs(machine, command="stat -c '%U %G' ${path1}", output = "user1 user1")
      outputs(machine, command="stat -c '%U %G' ${path2}", output = "user2 user2")

    with subtest("paths have the stated permissions"):
      outputs(machine, command="stat -c '%a' ${path1}", output="644")
      outputs(machine, command="stat -c '%a' ${path2}", output="755")

    with subtest("the unit recreates the directories when one is deleted"):
      machine.succeed("rm -r ${path1}")
      machine.systemctl("restart ensure-paths")
      machine.wait_for_unit("ensure-paths")
      machine.succeed("[ -d ${path1} ]")

    with subtest("the unit is not active when the paths exist"):
      machine.shutdown()
      machine.start()
      machine.fail("systemctl is-active --quiet ensure-paths")
  '';
}
