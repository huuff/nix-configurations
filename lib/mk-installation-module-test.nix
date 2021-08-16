{ pkgs, ... }:
let
  user = "user";
  path = "/var/user/path";
in
pkgs.nixosTest {
  name = "mk-installation-module";

  machine = { pkgs, ... }: {
    imports = [ ( import ./mk-installation-module.nix "test" ) ];

    machines.test.installation = { inherit user path; };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("user exists"):
      machine.succeed("grep -q ${user} /etc/passwd")

    with subtest("group exists"):
      machine.succeed("grep -q ${user} /etc/group")

    with subtest("user is in group"):
      machine.succeed("groups ${user} | grep -q ${user}")
  '';
}
