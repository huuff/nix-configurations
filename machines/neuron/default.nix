{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.neuron;
  neuronPkg = (builtins.getFlake "github:srid/neuron?rev=998fce27ccc91231ef9757e2bebeb39327850092").packages.x86_64-linux.neuron;
  gitWithoutDeployKey = "${pkgs.git}/bin/git";
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i ${cfg.deployKey} -o StrictHostKeyChecking=no -p ${toString cfg.sshPort}' '';
  gitCommand = if cfg.deployKey == null then gitWithoutDeployKey else gitWithDeployKey;
in
  {
    imports = 
    [
      ./cachix.nix
      ../../lib/do-on-request-module.nix
      (import ../../lib/mk-ssl-module.nix "neuron")
      (import ../../lib/mk-installation-module.nix "neuron")
      (import ../../lib/mk-init-module.nix "neuron")
    ];

    options.machines.neuron = with types; {
      enable = mkEnableOption "neuron";

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
        allowedTCPPorts = [ 80 ];
      };

      systemd.services.nginx.serviceConfig.ProtectHome = "read-only";

      machines.neuron.initialization.units = [
        { 
          name = "initialize-zettelkasten";
          description = "Create Zettelkasten directory and clone repository";
          script = ''
            echo ">>> Removing previous ${cfg.installation.path}"
            rm -rf ${cfg.installation.path}/{,.[!.],..?}* # weird but it will delete hidden files too without returning an error for . and ..
            echo ">>> Cloning ${cfg.repository} to ${cfg.installation.path}"
            ${gitCommand} clone "${cfg.repository}" ${cfg.installation.path} 
            echo ">>> Making ${cfg.installation.user} own ${cfg.installation.path}"
            chown -R ${cfg.installation.user}:${cfg.installation.user} ${cfg.installation.path}
          '';
          extraDeps = [ "network-online.target" ];
        }
      ];

      systemd.services.neuron = {
        description = "Watch and generate Neuron zettelkasten";

        serviceConfig = {
          User = cfg.installation.user;
          Restart = "always";
          WorkingDirectory = cfg.installation.path;
          ExecStart = "${cfg.package}/bin/neuron rib -w";
        };

        wantedBy = [ "multi-user.target" ];
      };

      services = {
        nginx = {
          enable = true;
          user = mkDefault cfg.installation.user;
          group = mkDefault cfg.installation.user;

          virtualHosts.neuron = {
            root = "${cfg.installation.path}/.neuron/output";
            locations."/".extraConfig = ''
              index index.html index.htm;

            '' + optionalString (cfg.passwordFile != null) ''
              auth_basic "Neuron";
              auth_basic_user_file ${cfg.passwordFile};
            '';
          };
        };

      };

      services = {
        do-on-request = {
          enable = true;
          user = cfg.installation.user;
          port = cfg.refreshPort;
          directory = "${cfg.installation.path}";
          script = "${gitCommand} pull";
        };
      };

      # Too coupled to the name of the unit
      systemd.services.do-on-request.wants = [ "finish-neuron-initialization.service" ];
    };
  }

