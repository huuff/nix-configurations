{ pkgs, testingLib, ... }:
let
  directory = "/home/neuron";
  refreshPort = 8999;
in
pkgs.nixosTest {
  name = "neuron";

  machine = { pkgs, ... }: {
    imports = [ ./default.nix ];

    machines.neuron = {
      enable = true;
      repository = "https://github.com/srid/alien-psychology.git";
      installation = {
        path = directory;
        ports.refresh = refreshPort;
      };
    };
  };

  testScript = ''
      ${ testingLib }

      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet neuron")
        machine.succeed("systemctl is-active --quiet do-on-request")
        machine.succeed("systemctl is-active --quiet finish-neuron-initialization")

      with subtest("directory is created"):
        machine.succeed("[ -d ${directory} ]")

      with subtest("repository was cloned"):
        machine.succeed("${pkgs.git}/bin/git -C ${directory} rev-parse")

      with subtest("neuron generates output"):
        machine.wait_until_succeeds("[ -e ${directory}/.neuron/output/index.html ]")

      with subtest("nginx is serving the zettelkasten"):
        machine.output_contains('curl localhost', '<h1 id="title-h1">Alien Psychology</h1>')
    '';
}
