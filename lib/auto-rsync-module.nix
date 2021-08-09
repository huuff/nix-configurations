{ pkgs, lib, config, ...}:
with lib;
let
  cfg = config.services.auto-rsync;
in
  {
    options.services.auto-rsync = with types; {
      enable = mkEnableOption "Enable auto-rsync";

      startPath = mkOption {
        type = oneOf [path str];
        description = "Path of the input";
      };

      endPath = mkOption {
        type = oneOf [path str];
        description = "Path of the output";
      };
    };

    config = mkIf cfg.enable {
      systemd.services.auto-rsync = {
        description = "Automatically rsync ${toString cfg.startPath} to ${toString cfg.endPath}";

        serviceConfig = {
          Restart = mkDefault "always";
        };

        wantedBy = [ "multi-user.target" ];

        script = ''
          #!${pkgs.stdenv.shell}
          set -euo pipefail
          while true; do
            echo "${cfg.startPath}" | ${pkgs.entr}/bin/entr -dnrs "${pkgs.rsync}/bin/rsync -rtvu ${cfg.startPath}/* ${cfg.endPath}"
          done;
        '';

      };
    };
  }
