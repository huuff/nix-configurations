{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.neuron;
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i ${cfg.deployKey} -o StrictHostKeyChecking=no' '';
in
  {
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
        type = oneOf [ str path ];
        description = "Path to the SSH key that will allow pulling the repository";
      };

      package = mkOption {
        type = package;
        default = pkgs.neuron-notes;
        description = "Neuron package used to generate zettelkasten";
      };
    };

    config = mkIf cfg.enable {
      imports = [
        ./cachix.nix
        (pkgs.fetchgit {
          url = "https://github.com/huuff/derivations";
          rev = "82a25a7bac0cee4a86144185741ed7390bad2f43"; 
        }).nixosModules.do-on-request
      ];

      networking.firewall = {
        allowedTCPPorts = [ 80 cfg.refreshPort ];
      };

      system.activationScripts = {
        createDir = ''
          echo ">>> Removing previous ${cfg.directory}"
          rm -rf ${cfg.directory}/{,.[!.],..?}* # weird but it will delete hidden files too without returning an error for . and ..
          echo ">>> Cloning ${cfg.repo} to ${cfg.directory}"
          ${gitWithDeployKey} clone "${cfg.repo}" ${cfg.directory} 
          echo ">>> Making ${cfg.user} own ${cfg.directory}"
          chown -R ${cfg.user}:${cfg.user} ${cfg.directory}
        '';
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
            '';
          };
        };

        do-on-request = {
          user = cfg.user;
          enable = true;
          port = cfg.refreshPort;
          workingDirectory = "${cfg.directory}";
          script = ''
            ${gitWithDeployKey} pull
          '';
        };
      };

      systemd.services.neuron = {
        description = "Watch and generate Neuron zettelkasten";

        serviceConfig = {
          User = cfg.user;
          Restart = "on-failure";
          WorkingDirectory = cfg.directory;
          ExecStart = "${cfg.package}/bin/neuron rib -w";
        };

        wantedBy = [ "default.target" ];

      };

    };
  }
