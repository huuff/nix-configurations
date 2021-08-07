{ pkgs, ... }:
let
  path = "/etc/ssl/test";
  nginxPath = "/var/www";
in
pkgs.nixosTest {
  name = "mk-ssl-module";

  machine = { pkgs, ... }: {
    imports = [ (import ./mk-ssl-module.nix "test") ];

    services.test.ssl = {
      enable = true;
      httpsOnly = true;
      user = "nginx";
      inherit path;
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
    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet create-test-cert")

    with subtest("certificate exists"):
      machine.succeed("[ -e ${path}/cert.pem ]")
      machine.succeed("[ -e ${path}/key.pem ]")

    with subtest("unit creates a new certificate if one is missing"):
      machine.succeed("rm ${path}/*")
      machine.systemctl("restart create-test-cert")
      machine.wait_for_unit("create-test-cert")
      machine.succeed("[ -e ${path}/cert.pem ]")
      machine.succeed("[ -e ${path}/key.pem ]")

    with subtest("can access nginx with https"):
      machine.succeed("curl -k https://localhost")

    with subtest("cannot access nginx without https"):
      [ _, out ] = machine.execute("curl -s -o /dev/null -w '%{http_code}' http://localhost")
      assert out == "301"

    with subtest("unit is not started if the certificate exists"):
      machine.systemctl("restart create-test-cert")
      machine.fail("systemctl is-active --quiet create-test-cert")
  '';
}
