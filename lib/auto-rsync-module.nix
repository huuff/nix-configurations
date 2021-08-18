{ pkgs, lib, config, ...}:
with lib;
let
  cfg = config.services.auto-rsync;
in
  {
    options = with types; {
      services.auto-rsync = {
        enable = mkEnableOption "auto-rsync";

        startPath = mkOption {
          type = oneOf [path str];
          description = "Path of the input";
        };

        endPath = mkOption {
          type = oneOf [path str];
          description = "Path of the output";
        };
      };
    };

    config = mkIf cfg.enable {
      systemd.services.auto-rsync = {
        description = "Automatically rsync ${toString cfg.startPath} to ${toString cfg.endPath}";

        serviceConfig = {
          Restart = mkDefault "always";
        };

        path = with pkgs; [ inotify-tools rsync ];

        wantedBy = [ "multi-user.target" ];

        script = ''
          inotifywait -m "${cfg.startPath}" -e create -e moved_to -e modify |
            while read dir action file; do
              rsync -rtvu ${cfg.startPath}/* ${cfg.endPath}
            done
        '';

      };
    };
  }
