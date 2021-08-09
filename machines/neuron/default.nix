{ neuronPkg }:

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.neuron;
  gitWithoutDeployKey = "${pkgs.git}/bin/git";
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i ${cfg.deployKey} -o StrictHostKeyChecking=no -p ${toString cfg.sshPort}' '';
  gitCommand = if isNull cfg.deployKey then gitWithoutDeployKey else gitWithDeployKey;
  mkSSLModule = import ../../lib/mk-ssl-module.nix;
  mkInstallationModule = import ../../lib/mk-installation-module.nix;
in
  {
    imports = 
    [
      ./cachix.nix
      ../../lib/do-on-request.nix
      (mkSSLModule "neuron")
      (mkInstallationModule "neuron")
    ];

    options.services.neuron = with types; {
      enable = mkEnableOption "Automatically fetch Neuron zettelkasten from git repo and serve it";

      refreshPort = mkOption {
        type = int;
        default = 55000;
        description = "Sending a request to this port will trigger a git pull to refresh the zettelkasten from a repo.";
      };

      repository = mkOption {
        type = str;
        description = "Repository that holds the zettelkasten";
      };

      deployKey = mkOption {
        type = nullOr (oneOf [ str path ]);
        default = null;
        description = "Path to the SSH key that will allow pulling the repository";
      };

      sshPort = mkOption {
        type = int;
        default = 22;
        description = "If you, for some reason, have changed the default SSH port, you'll need to specify it here for cloning the repository";
      };

      package = mkOption {
        type = package;
        default = neuronPkg;
        description = "Neuron package used to generate zettelkasten";
      };

      passwordFile = mkOption {
        type = nullOr (oneOf [ path str ]);
        default = null;
        description = "Location of the htpasswd file that contains the password for HTTP basic authentication";
      };
    };

    config = mkIf cfg.enable {
      networking.firewall = {
        allowedTCPPorts = [ 80 cfg.refreshPort ];
      };

      systemd.services.nginx.serviceConfig.ProtectHome = "read-only";

      systemd.services = {
        initialize-zettelkasten = {
          description = "Create Zettelkasten directory and clone repository";

          script = ''
            echo ">>> Removing previous ${cfg.installation.path}"
            rm -rf ${cfg.installation.path}/{,.[!.],..?}* # weird but it will delete hidden files too without returning an error for . and ..
            echo ">>> Cloning ${cfg.repository} to ${cfg.installation.path}"
            ${gitCommand} clone "${cfg.repository}" ${cfg.installation.path} 
            echo ">>> Making ${cfg.installation.user} own ${cfg.installation.path}"
            chown -R ${cfg.installation.user}:${cfg.installation.user} ${cfg.installation.path}
          '';

          wantedBy = [ "do-on-request.service" ];
          wants = [ "network.target" ];

          unitConfig = {
            Before = [ "do-on-request.service" ];
            Requires = [ "network.target" ];
            After = [ "network.target" ];
          };

          serviceConfig = {
            User = cfg.installation.user;
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };

        neuron = {
          description = "Watch and generate Neuron zettelkasten";

          serviceConfig = {
            User = cfg.installation.user;
            Restart = "always";
            WorkingDirectory = cfg.installation.path;
            ExecStart = "${cfg.package}/bin/neuron rib -w";
          };

          wantedBy = [ "multi-user.target" ];

        };
      };

      services = {
        nginx = {
          enable = true;
          user = cfg.installation.user;
          group = cfg.installation.user;

          virtualHosts.neuron = {
            root = "${cfg.installation.path}/.neuron/output";
            locations."/".extraConfig = ''
              index index.html index.htm;

            '' + optionalString (!isNull cfg.passwordFile) ''
               auth_basic "Neuron";
               auth_basic_user_file ${cfg.passwordFile};
            '';
          };
        };

        do-on-request = {
          user = cfg.installation.user;
          enable = true;
          port = cfg.refreshPort;
          workingDirectory = "${cfg.installation.path}";
          script = ''
            ${gitCommand} pull
          '';
        };
      };
    };
  }

