{ pkgs, lib, config, ... }: 
with lib;
let
  cfg = config.services.neuron;
  #auto-rsync = pkgs.writeScriptBin "auto-rsync" ''
    ##!${pkgs.stdenv.shell}
    #set -euo pipefail
    #${pkgs.fd}/bin/fd . ${cfg.path}/.neuron/output | ${pkgs.entr}/bin/entr -n -s "${pkgs.rsync}/bin/rsync -rtvu ${cfg.path}/.neuron/output/* /var/www/neuron"
    #'';
in
  {
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
      systemd.services.rsync-neuron = {
        description = "rsync output to /var/www/neuron";

        preStart = ''
          mkdir -p /var/www/neuron
          chown nginx:nginx /var/www/neuron
          chmod 0755 /var/www/neuron
        '';

        serviceConfig = {
          Restart = "on-failure";
          #ExecStart = "${auto-rsync}/bin/auto-rsync";
        };

        wantedBy = [ "default.target" ];

        script = ''
    #!${pkgs.stdenv.shell}
          set -euo pipefail
          ${pkgs.fd}/bin/fd . ${cfg.path}/.neuron/output | ${pkgs.entr}/bin/entr -n -s "${pkgs.rsync}/bin/rsync -rtvu ${cfg.path}/.neuron/output/* /var/www/neuron"
        '';
      };

      services.nginx = {
        enable = true;
        appendHttpConfig = ''
            disable_symlinks off;
        '';

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

