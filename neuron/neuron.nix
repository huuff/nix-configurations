{ config, pkgs, repo, keyPath, ... }:
let
  zettelDir = "/home/neuron";
  actionPort = 55000; # TODO: Make it a parameter
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i ${keyPath} -o StrictHostKeyChecking=no' '';
in
  {
    networking.firewall = {
      allowedTCPPorts = [ 80 actionPort];
    };

    system.activationScripts = {
      createDir = ''
        echo "START ACTIVATION SCRIPT"
        echo "Removing previous ${zettelDir}"
        rm -r ${zettelDir}
        echo "Cloning ${repo} to ${zettelDir}"
        ${gitWithDeployKey} clone "${repo}" ${zettelDir} 
        echo "Making neuron own ${zettelDir}"
        chown -R neuron:neuron ${zettelDir}
        '';
    };

    users.users.neuron = {
      isSystemUser = true;
      home = "${zettelDir}";
      group = "neuron";
      extraGroups = [ "keys" ]; # needed so it can access /run/keys
      createHome = true;
    };

    users.groups.neuron = {};

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

  }
