{ pkgs, doOnRequest, neuronPkg, ... }:
# Test are quite expensive to set up, so I'll test everything here
let
  directory = "/home/neuron";
in
pkgs.nixosTest {
  name = "neuron";

  machine = { pkgs, ... }: {
    imports = [ (import ./default.nix { inherit doOnRequest neuronPkg; }) ];

    environment.systemPackages = with pkgs; [ git ];

    nix.useSandbox = false;
    
    services.neuron = {
      enable = true;
      repository = "https://github.com/srid/alien-psychology.git";
      refreshPort = 8999;
      inherit directory;
    };
  };

  testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet neuron")
        machine.succeed("systemctl is-active --quiet do-on-request")
        machine.succeed("systemctl is-active --quiet nginx")

      with subtest("directory is created"):
        machine.succeed("[ -d ${directory} ]")

      with subtest("repository was cloned"):
        machine.succeed("git -C ${directory} rev-parse")

      with subtest("neuron generates output"):
        machine.wait_until_succeeds("[ -e /home/neuron/.neuron/output/index.html ]")

      with subtest("nginx is serving the zettelkasten"):
        [status, out] = machine.execute('curl localhost:80')
        assert '<h1 id="title-h1">Alien Psychology</h1>' in out
    '';
}
