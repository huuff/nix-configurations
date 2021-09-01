{ pkgs, testingLib, ... }:
let
  directory = "/home/neuron";
  refreshPort = 8999;
  oldCommit = "6b57be4";
in
pkgs.nixosTest {
  name = "neuron";

  machine = { pkgs, ... }: {
    imports = [ ./default.nix ];

    environment.systemPackages = with pkgs; [ git ];

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
        machine.succeed("git -C ${directory} rev-parse")

      with subtest("neuron generates output"):
        machine.wait_until_succeeds("[ -e ${directory}/.neuron/output/index.html ]")

      with subtest("nginx is serving the zettelkasten"):
        machine.output_contains('curl localhost', '<h1 id="title-h1">Alien Psychology</h1>')

      with subtest("repository is pulled on request"):
        # First, let's save the current commit
        [ _, newCommit ] = machine.execute("cd ${directory} && git rev-parse --short HEAD")
        newCommit = newCommit.strip()
        # Then we reset to an older one
        machine.execute("cd ${directory} && git reset --hard ${oldCommit}")
        # Sanity check that we are at an older commit
        machine.succeed('[ "$(cd ${directory} && git rev-parse --short HEAD)" = "${oldCommit}" ]')
        # Finally, trigger a pull and check that it happened
        machine.execute("${pkgs.curl}/bin/curl localhost:${toString refreshPort}")
        machine.wait_until_succeeds(f'[ "$(cd ${directory} && git rev-parse --short HEAD)" = "{newCommit}" ]')
    '';
}
