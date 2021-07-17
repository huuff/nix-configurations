{ config, pkgs, repo, keyPath, actionPort ? 55000, directory ? "/home/neuron", user ? "neuron", ... }:
let
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i ${keyPath} -o StrictHostKeyChecking=no' '';
in
  {
    networking.firewall = {
      allowedTCPPorts = [ 80 actionPort];
    };

    system.activationScripts = {
      createDir = ''
        echo "START ACTIVATION SCRIPT"
        echo "Removing previous ${directory}"
        rm -rf ${directory}/{,.[!.],..?}* # weird but it will delete hidden files too without returning an error for . and ..
        echo "Cloning ${repo} to ${directory}"
        ${gitWithDeployKey} clone "${repo}" ${directory} 
        echo "Making ${user} own ${directory}"
        chown -R ${user}:${user} ${directory}
        '';
    };

    users.users.${user} = {
      isSystemUser = true;
      home = "${directory}";
      group = user;
      extraGroups = [ "keys" ]; # needed so it can access /run/keys
      createHome = true;
    };

    users.groups.${user} = {};

    systemd.services.nginx.serviceConfig.ProtectHome = "read-only";

    services = {
      nginx = {
        enable = true;
        inherit user;
        group = user;
        virtualHosts.neuron = {
          enableACME = false;
          root = "${directory}/.neuron/output";
          locations."/" = {
            extraConfig = ''
              index index.html index.htm;
            '';
          };
        };
      };

      do-on-request = {
        inherit user;
        enable = true;
        port = actionPort;
        workingDirectory = "${directory}";
        script = ''
          ${gitWithDeployKey} pull
        '';
      };

      neuron = {
        inherit user;
        enable = true;
        path = "${directory}";
      };
    };

  }
