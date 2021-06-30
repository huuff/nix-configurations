{ config, pkgs, repo, ... }:
let
  zettelDir = "/home/neuron";
  actionPort = 55000; # TODO: Make it a parameter
in
  {
    networking.firewall = {
      allowedTCPPorts = [ 80 actionPort];
    };

    system.activationScripts = {
      createDirs = "mkdir ${zettelDir}";
    };

    services = {
       # I can't for the life of me serve from the user directory (permissions fucking me over)
      # So this is my best solution
      auto-rsync = {
        startPath = "${zettelDir}/.neuron/output";
        endPath = "/var/www/neuron";
        createStartPath = false;
        createEndPath = true;
        preScript = ''
            chown nginx:nginx /var/www/neuron
            chmod 0755 /var/www/neuron
        '';
      };

      nginx = {
        enable = true;

        virtualHosts.neuron = {
          enableACME = false;
          root = "/var/www/neuron";
          locations."/" = {
            extraConfig = ''
              index index.html index.htm;
            '';
          };
        };
      };

      do-on-request = 
      let
        sshWithDeployKey = ''core.sshCommand=${pkgs.openssh}/bin/ssh -i /run/keys/deploy -o StrictHostKeyChecking=no'';
      in
      {
        enable = true;
        port = actionPort;
        workingDirectory = "${zettelDir}";
        preScript = ''
          ${pkgs.git}/bin/git -c '${sshWithDeployKey}' clone "${repo}" ${zettelDir} || true
        '';
        script = ''
          ${pkgs.git}/bin/git -c '${sshWithDeployKey}' pull
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
