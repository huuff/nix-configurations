{ config, pkgs, repo, ... }:
let
  zettelDir = "/home/neuron";
  actionPort = 55000; # TODO: Make it a parameter
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i /run/keys/deploy -o StrictHostKeyChecking=no' '';
in
  {
    networking.firewall = {
      allowedTCPPorts = [ 80 actionPort];
    };

    system.activationScripts = {
      cloneRepo = ''${gitWithDeployKey} clone "${repo}" ${zettelDir} || true'';
    };

  systemd.services.nginx.serviceConfig.ProtectHome = "read-only";

    services = {
      nginx = {
        enable = true;
        user = "neuron";
        group = "neuron";
        virtualHosts.neuron = {
          enableACME = false;
          root = "${zettelDir}/.neuron/output";
          locations."/" = {
            extraConfig = ''
              index index.html index.htm;
            '';
          };
        };
      };

      do-on-request = {
        enable = true;
        port = actionPort;
        user = "neuron";
        workingDirectory = "${zettelDir}";
        script = ''
          ${gitWithDeployKey} pull
        '';
      };


      neuron = {
        enable = true;
        path = "${zettelDir}";
      };

      openssh = {
        enable = true;
        permitRootLogin = "yes";
      };
    };

    users.users.neuron = {
      isSystemUser = true;
      home = "${zettelDir}";
      group = "neuron";
      createHome = true;
    };

    users.groups.neuron = {};
  }
