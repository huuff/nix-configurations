{ pkgs, neuronPkg, ... }:
let
  directory = "/home/neuron";
in
pkgs.nixosTest {
  name = "neuron";

  machine = { pkgs, ... }: {
    imports = [ (import ./default.nix { inherit neuronPkg; }) ];

    nix.useSandbox = false;
    
    services.neuron = {
      enable = true;
      repository = "https://github.com/srid/alien-psychology.git";
      refreshPort = 8999;
      installation.path = directory;
    };
  };

  testScript = ''
      ${ builtins.readFile ../../lib/testing-lib.py }

      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet neuron")
        machine.succeed("systemctl is-active --quiet do-on-request")
        machine.succeed("systemctl is-active --quiet nginx")

      with subtest("directory is created"):
        machine.succeed("[ -d ${directory} ]")

      with subtest("repository was cloned"):
        machine.succeed("${pkgs.git}/bin/git -C ${directory} rev-parse")

      with subtest("neuron generates output"):
        machine.wait_until_succeeds("[ -e ${directory}/.neuron/output/index.html ]")

      with subtest("nginx is serving the zettelkasten"):
        outputContains(machine, 'curl localhost', '<h1 id="title-h1">Alien Psychology</h1>')
    '';
}
