{ pkgs, lib, config, ... }: 
with lib;
let
  cfg = config.services.neuron;
in
  {
    #imports = [
      #./auto-rsync.nix
    #];

    options.services.neuron = {
      enable = mkEnableOption "Automatically serve Neuron";

      path = mkOption {
        type = types.str;
        default = null;
        description = "Path of the zettelkasten root";
      };
    };

    config = mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.path != null;
          message = "services.neuron.path must be set!";
        }
      ];

      systemd.services.neuron = {
        description = "Neuron instance";

        serviceConfig = {
          Restart = "on-failure";
          WorkingDirectory = cfg.path;
          ExecStart = "${pkgs.neuron-notes}/bin/neuron rib -w";
        };

        wantedBy = [ "default.target" ];

      };

      # I can't for the life of me serve from the user directory (permissions fucking me over)
      # So this is my best solution
      services.auto-rsync = {
        startPath = "${cfg.path}/.neuron/output";
        endPath = "/var/www/neuron";
        preScript = ''
            chown nginx:nginx /var/www/neuron
            chmod 0755 /var/www/neuron
          '';
      };
    
      services.nginx = {
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
    };
  }

