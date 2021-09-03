{ name, repository, borgLib, ... }:
{ pkgs, config, lib, ... }:

with lib;
let
  cfg = config.machines.${name}.backup;
in
{
  options = {
    machines.${name}.backup.directories = with types; {
      enable = mkEnableOption "directory backup";

      paths = mkOption {
        type = listOf (oneOf [ str path ]);
        default = [];
        description = "List of paths that will be backed up";
      };

      repository = mkOption {
        type = repository;
        default = {};
        description = "Options for the borg repository where the directories backup will be stored";
      };

    };
  };

  config = {
    
    machines.${name}.initialization.units = 
        (mkAfter [
          (mkIf (cfg.restore && cfg.directories.enable) {
            name = "restore-${name}-directories-backup";
            description = "Restore the latest ${name} directories backup";
            path = with pkgs; [ borgbackup openssh rsync ];
            script = let 
              repo = cfg.directories.repository;
              paths = concatStringsSep " " (map (path: ''"${toString path}"'') cfg.directories.paths);
            in ''
              ${borgLib.setEnv repo}
              if ${borgLib.repoNotEmpty repo}; then
                latest_archive=${borgLib.latestArchive repo}
                
                tmp_dir=$(mktemp -d)
                trap "rm -rf $tmp_dir" EXIT

                cd $tmp_dir
                borg extract ${borgLib.buildPath repo}::"$latest_archive"
                rm -rf ${paths}
                rsync -a . /
              fi
            '';
            user = "root";
          })
        ]);

    systemd = {
      tmpfiles.rules = mkIf (cfg.directories.enable && cfg.directories.repository.localPath != null) ["d ${cfg.directories.repository.localPath} 700 ${cfg.user} ${cfg.user} - -"];


      timers."backup-${name}-directories" = mkIf cfg.directories.enable {
        wantedBy = [ "timers.target" ];

        partOf = [ "backup-${name}-directories.service" ];

        timerConfig.OnCalendar = cfg.frequency;
      };

      services."backup-${name}-directories" = mkIf cfg.directories.enable {
        description = "Make a backup of the ${name} directories";

        path = with pkgs; [ borgbackup openssh ];

        script = let repo = cfg.directories.repository; in ''
          ${borgLib.setEnv repo}
          borg create ${borgLib.compressionArg cfg} ${borgLib.buildPath repo}::{now} ${concatStringsSep " " (map (path: ''"${path}"'') cfg.directories.paths)}
        '';

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
        };
      };
    };
  };
}
