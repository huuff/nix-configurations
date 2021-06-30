{ pkgs, lib, config, ... }: 
with lib;
let
  cfg = config.services.neuron;
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

    };
  }

