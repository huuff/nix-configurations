{ pkgs, ... }:
let
  path1 = "/var/path1";
  path2 = "/var/midpath/path2";
in
pkgs.nixosTest {
  name = "ensure-paths";

  machine = { pkgs, ... }: {
    imports = [ ./ensure-paths-module.nix ];

    services.ensurePaths = [
      { path = path1; owner = "user1"; permissions = "644"; }
      { path = path2; owner = "user2"; permissions = "755"; }
    ];

    users.users.user1.isSystemUser = true;
    users.groups.user1 = {};
    users.users.user2.isSystemUser = true;
    users.groups.user2 = {};
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet ensure-paths")

    with subtest("paths exist"):
      machine.succeed("[ -d ${path1} ]")
      machine.succeed("[ -d ${path2} ]")

    with subtest("paths belong to their owners"):
      [ _, out ] = machine.execute("stat -c '%U %G' ${path1}")
      assert out == "user1 user1\n"
      [ _, out ] = machine.execute("stat -c '%U %G' ${path2}")
      assert out == "user2 user2\n"

    with subtest("paths have the stated permissions"):
      [ _, out ] = machine.execute("stat -c '%a' ${path1}")
      assert out == "644\n"
      [ _, out ] = machine.execute("stat -c '%a' ${path2}")
      assert out == "755\n"

    with subtest("the unit is not active when the paths exist"):
      machine.shutdown()
      machine.start()
      machine.fail("systemctl is-active --quiet ensure-paths")


  '';
}
