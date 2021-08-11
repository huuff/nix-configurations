{ pkgs, ... }:
let
  startPath = "/var/startPath";
  endPath = "/var/endPath";
in
pkgs.nixosTest {
  name = "auto-rsync";

  machine = { pkgs, ... }: {
    imports = [ ./auto-rsync-module.nix ./ensure-paths-module.nix ];

    machines.ensurePaths = [
      { path = startPath; }
      { path = endPath; }
    ];

    machines.auto-rsync = {
      enable = true;
      inherit startPath endPath;
    };

  };

  testScript = ''
    ${ builtins.readFile ./testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet auto-rsync")

    with subtest("files added to the startpath are copied to the endpath"):
      machine.execute("touch ${startPath}/file1")
      machine.execute("touch ${startPath}/file2")
      machine.sleep(2)
      machine.succeed("[ -e ${endPath}/file1 ]")
      machine.succeed("[ -e ${endPath}/file2 ]")
  '';
}
