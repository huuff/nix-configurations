{ pkgs, testingLib, ... }:
let
  group = "group";
  osticketPort = 8080;
  wallabagPort = 8081;
  neuronPort = 8082;
in
  pkgs.nixosTest {
    name = "multi-deploy";

    machine = { pkgs, config, lib, ... }:
    with lib;
    {
      imports = [
        ./default.nix
        ../../machines/osticket
        ../../machines/wallabag
        ../../machines/neuron
      ];

    multi-deploy.group = group;

    virtualisation = {
      memorySize = "2048M";
      diskSize = 5 * 1024;
    };

    machines = {
      osticket = {
        enable = true;

        installation = {
          ports.http = osticketPort;
        };

        database = {
          authenticationMethod = "password";
          passwordFile = pkgs.writeText "dbpass" "dbpass";
        };

        admin = {
          passwordFile = pkgs.writeText "pass" "pass";
        };

      };

      wallabag = {
        enable = true;

        installation = {
          ports.http = wallabagPort;
        };
      };

      neuron = {
        enable = true;
        repository = "https://github.com/srid/alien-psychology.git";

        installation = {
          ports.http = neuronPort;
        };
      };
    };

    services.nginx.user = mkForce "nginx";
  };

  testScript = ''
    ${ testingLib }

    machine.wait_for_unit("multi-user.target")

    with subtest("all services deployed"):
      machine.succeed("systemctl is-active --quiet finish-wallabag-initialization")
      #machine.succeed("systemctl is-active --quiet finish-neuron-initialization")
      machine.succeed("systemctl is-active --quiet finish-osticket-initialization")

    with subtest("neuron is being serve"):
      machine.output_contains('curl localhost:${toString neuronPort}', '<h1 id="title-h1">Alien Psychology</h1>')

    with subtest("osticket is being served"):
      machine.output_contains('curl localhost:${toString osticketPort}', "<h1>Welcome to the Support Center</h1>") 

    with subtest("wallabag is being served"):
      machine.output_contains('curl localhost:${toString wallabagPort}/login', '<title>Welcome to wallabag! – wallabag</title>')
  '';
}
