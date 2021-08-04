{ pkgs, ... }:
let
  path = "/var/ssl";
in
pkgs.nixosTest {
  name = "mk-ssl-module";

  machine = { pkgs, ... }: {
    imports = [ (import ./mk-ssl-module.nix "test") ];

    services.test.ssl = {
      enable = true;
      inherit path;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet create-test-cert")

    with subtest("certificate exists"):
      machine.succeed("[ -e ${path}/cert.pem ]")
      machine.succeed("[ -e ${path}/key.pem ]")

    with subtest("unit creates a new certificate if one is missing"):
      machine.succeed("rm /var/ssl/*")
      machine.systemctl("restart create-test-cert")
      machine.wait_for_unit("create-test-cert")
      machine.succeed("[ -e ${path}/cert.pem ]")
      machine.succeed("[ -e ${path}/key.pem ]")

    with subtest("unit is not started if the certificate exists"):
      machine.shutdown()
      machine.start()
      machine.fail("systemctl is-active --quiet create-test-cert")
  '';
}
