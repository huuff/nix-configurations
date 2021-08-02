{ doOnRequest, neuronPkg }:

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.neuron;
  gitWithoutDeployKey = "${pkgs.git}/bin/git";
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i ${cfg.deployKey} -o StrictHostKeyChecking=no -p ${toString cfg.sshPort}' '';
  gitCommand = if isNull cfg.deployKey then gitWithoutDeployKey else gitWithDeployKey;
in
  {
    imports = 
    [
      ./cachix.nix
      doOnRequest
    ];

    options.services.neuron = with types; {
      enable = mkEnableOption "Automatically fetch Neuron zettelkasten from git repo and serve it";

      refreshPort = mkOption {
        type = int;
        default = 55000;
        description = "Sending a request to this port will trigger a git pull to refresh the zettelkasten from a repo.";
      };

      directory = mkOption {
        type = oneOf [ str path ];
        default = "/home/neuron";
        description = "Directory from which to serve the zettelkasten";
      };

      user = mkOption {
        type = str;
        default = "neuron";
        description = "User that will save and serve Neuron";
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
        description = "If you, for some reason, have changed the default SSH port, you'll need to specify here for cloning the repository";
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

      users.users.${cfg.user} = {
        isSystemUser = true;
        home = "${cfg.directory}";
        group = cfg.user;
        extraGroups = [ "keys" ]; # needed so it can access /run/keys
        createHome = true;
      };

      users.groups.${cfg.user} = {};

      systemd.services.nginx.serviceConfig.ProtectHome = "read-only";

      systemd.services = {
        initialize-zettelkasten = {
          description = "Create Zettelkasten directory and clone repository";

          script = ''
            echo ">>> Removing previous ${cfg.directory}"
            rm -rf ${cfg.directory}/{,.[!.],..?}* # weird but it will delete hidden files too without returning an error for . and ..
            echo ">>> Cloning ${cfg.repository} to ${cfg.directory}"
            ${gitCommand} clone "${cfg.repository}" ${cfg.directory} 
            echo ">>> Making ${cfg.user} own ${cfg.directory}"
            chown -R ${cfg.user}:${cfg.user} ${cfg.directory}
          '';

          wantedBy = [ "do-on-request.service" ];

          unitConfig = {
            Before = [ "do-on-request.service" ];
          };

          serviceConfig = {
            User = cfg.user;
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };

        neuron = {
          description = "Watch and generate Neuron zettelkasten";

          serviceConfig = {
            User = cfg.user;
            Restart = "always";
            WorkingDirectory = cfg.directory;
            ExecStart = "${cfg.package}/bin/neuron rib -w";
          };

          wantedBy = [ "multi-user.target" ];

        };
      };

      services = {
        nginx = {
          enable = true;
          user = cfg.user;
          group = cfg.user;

          virtualHosts.neuron = {
            enableACME = false;
            root = "${cfg.directory}/.neuron/output";
            locations."/".extraConfig = ''
              index index.html index.htm;

            '' + optionalString (!isNull cfg.passwordFile) ''
               auth_basic "Neuron";
               auth_basic_user_file ${cfg.passwordFile};
            '';
          };
        };

        do-on-request = {
          user = cfg.user;
          enable = true;
          port = cfg.refreshPort;
          workingDirectory = "${cfg.directory}";
          script = ''
            ${gitCommand} pull
          '';
        };
      };
    };
  }
