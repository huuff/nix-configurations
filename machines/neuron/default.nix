{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.neuron;
  neuronPkg = (builtins.getFlake "github:srid/neuron?rev=998fce27ccc91231ef9757e2bebeb39327850092").packages.x86_64-linux.neuron;
  myLib = import ../../lib { inherit config pkgs lib; };

  gitWithoutDeployKey = "${pkgs.git}/bin/git";
  gitWithDeployKey = ''${pkgs.git}/bin/git -c 'core.sshCommand=${pkgs.openssh}/bin/ssh -i ${cfg.deployKey} -o StrictHostKeyChecking=no -p ${toString cfg.sshPort}' '';
  gitCommand = if cfg.deployKey == null then gitWithoutDeployKey else gitWithDeployKey;
in
  {
    imports = 
    [
      ./cachix.nix
      ../../modules/do-on-request
      (import ../../modules/ssl "neuron")
      (import ../../lib/mk-installation-module.nix "neuron")
      (import ../../lib/mk-init-module.nix "neuron")
    ];

    options.machines.neuron = with types; {
      enable = mkEnableOption "neuron";

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
    };

    config = mkIf cfg.enable {
      systemd.services.nginx.serviceConfig.ProtectHome = "read-only";

      machines.neuron = {
        initialization.units = [
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

        installation.ports = myLib.mkDefaultHttpPorts cfg // {
          refresh = mkDefault 55000;
        };

      };

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
          group = mkDefault cfg.installation.group;

          virtualHosts.neuron = {
            root = "${cfg.installation.path}/.neuron/output";

            listen = myLib.mkListen cfg;

            locations."/".extraConfig = ''
              index index.html index.htm;
              '';
          };
        };

      };

      services = {
        do-on-request = {
          enable = true;
          user = cfg.installation.user;
          port = cfg.installation.ports.refresh;
          directory = "${cfg.installation.path}";
          script = "${gitCommand} pull";
        };
      };

      # Too coupled to the name of the unit
      systemd.services.do-on-request.wants = [ "finish-neuron-initialization.service" ];
    };
  }

