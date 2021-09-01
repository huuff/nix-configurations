{ pkgs, testingLib, ... }:
let
  startPath = "/var/startPath";
  endPath = "/var/endPath";
in
pkgs.nixosTest {
  name = "auto-rsync";

  machine = { pkgs, ... }: {
    imports = [ ./auto-rsync-module.nix ];

    systemd.tmpfiles.rules = [
      "d ${startPath} 0777 root root - -"
      "d ${endPath} 0777 root root - -"
    ];

    services.auto-rsync = {
      enable = true;
      inherit startPath endPath;
    };

  };

  testScript = ''
    ${ testingLib }

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
