{ pkgs, ... }:
let
  nginxPath = "/var/www";
  certPath = "/etc/ssl/certs/test.pem";
  keyPath = "/etc/ssl/private/test.pem";
in
pkgs.nixosTest {
  name = "mk-ssl-module";

  machine = { pkgs, ... }: {
    imports = [ (import ./mk-ssl-module.nix "test") ];

    machines.test.ssl = {
      enable = true;
      httpsOnly = true;
      user = "nginx";
    };

    system.activationScripts.createTestContent.text = ''
        mkdir -p ${nginxPath}
        echo "<h1>Hello World</h1>" >> ${nginxPath}/index.html
      '';

    services.nginx = {
      enable = true;

      virtualHosts.test = {
        root = nginxPath;
        locations."/".extraConfig = ''
            index index.html;
          '';
      };
    };
  };

  testScript = ''
    ${ builtins.readFile ./testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet create-test-cert")

    with subtest("certificate exists"):
      machine.succeed("[ -e ${certPath} ]")
      machine.succeed("[ -e ${keyPath} ]")

    with subtest("unit creates a new certificate if one is missing"):
      machine.succeed("rm ${certPath} ${keyPath}")
      # Sanity check that they have been deleted
      machine.fail("[ -e ${certPath} ]")
      machine.fail("[ -e ${keyPath} ]")
      machine.systemctl("restart create-test-cert")
      machine.wait_for_unit("create-test-cert")
      machine.succeed("[ -e ${certPath} ]")
      machine.succeed("[ -e ${keyPath} ]")

    with subtest("can access nginx with https"):
      machine.succeed("curl -k https://localhost")

    with subtest("cannot access nginx without https"):
      machine.outputs("curl -s -o /dev/null -w '%{http_code}' http://localhost", "301")

    with subtest("unit is not started if the certificate exists"):
      machine.systemctl("restart create-test-cert")
      machine.fail("systemctl is-active --quiet create-test-cert")
  '';
}
