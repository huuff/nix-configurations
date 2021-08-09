{ pkgs, ... }:
let
  port = 9999;
  file = "/var/test";
  testWord = "triggered";
in
pkgs.nixosTest {
  name = "do-on-request";

  machine = { pkgs, ... }: {
    imports = [ ./do-on-request-module.nix ];

    services.do-on-request = {
      enable = true;
      script = "echo '${testWord}' >> ${file}";
      inherit port;
    };
  };

  testScript = ''
    ${ builtins.readFile ./testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet do-on-request")

    with subtest("3 requests handled correctly"):
      for i in range(3):
        machine.execute("curl localhost:${toString port} --max-time '0.1'")

    outputs(machine, "cat ${file} | grep ${testWord} | wc -l", "4")
  '';
}
