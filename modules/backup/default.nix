# TODO: DRY this. e.g. some function that sets all environment variables
# TODO: Maybe passphrase from file descriptor? This might allow less eavesdropping
name:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.${name}.backup;
  dbCfg = config.machines.${name}.database;

  myLib = import ../../lib/default.nix { inherit config pkgs lib; };
  borgLib = import ./borg-lib.nix { inherit lib myLib; };

  remote = with types; submodule {
    options = {
      user = mkOption {
        type = str;
        default = null;
        description = "User that will be used to connect through SSH to the repository";
      };

      hostname = mkOption {
        type = str;
        default = null;
        description = "Hostname where backups will be sent";
      };

      key = mkOption {
        type = oneOf [ path str ];
        default = null;
        description = "Path of the key used to connect through ssh to the repository";
      };

      path = mkOption {
        type = str;
        default = null;
        description = "Path where the archive will be created";
      };
    };
  };


  repository = with types; submodule {
    options = { 
      localPath = mkOption {
        type = nullOr (oneOf [ str path ]);
        default = "/var/lib/backup/${name}";
        description = "Path where the backup will be stored, if remote, do not use the 'ssh://' format, but fill in the remote option";
      };

      remote = mkOption {
        type = nullOr remote;
        default = null;
        description = "SSH options for a remote repository";
      };

      encryption = {
        mode = mkOption {
          type = enum [ "none" "authenticated" "repokey" "keyfile" ];
          default = "none";
          description = "Encryption mode to use";
        };

        passphraseFile = mkOption {
          type = nullOr (oneOf [ str path ]);
          default = null;
          description = "Encryption key passphrase";
        };
      };
    };
  };
in
  {
    options = with types; {
      machines.${name}.backup = {
        user = mkOption {
          type = str;
          default = config.machines.${name}.installation.user or null;
          description = "User that will run the backup script";
        };

        directories = {
          enable = mkEnableOption "directory backup";

          # TODO: Ensure paths are absolute
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

        database = {
          enable = mkEnableOption "database backup";

          repository = mkOption {
            type = repository;
            default = {};
            description = "Options for the borg repository where the database backup will be stored";
          };
        };

        restore = mkOption {
          type = bool;
          default = false;
          description = ''
            Automatically restore the latest backup after initialization.
            This is a destructive operation since all previous files/databaes will be replaced by the contents of the backup.
            '';
        };
      };
    };

    config = {
      assertions = [
        {
          assertion = cfg.database.enable -> config.machines.${name}.backup.database.enable;
          message = "Can't enable database backup without enabling database!";
        }
        {
          assertion = ((cfg.database.repository.localPath != null) -> cfg.database.repository.remote == null) && ((cfg.directories.repository.localPath != null) -> cfg.directories.repository.remote == null);
          message = "You can't set a path and a remote at the same time for a repository!";
        }
      ];

      machines.${name}.initialization.units = mkMerge [ 
        (mkBefore [
          (mkIf (cfg.database.enable || cfg.directories.enable) {
            name = "initialize-${name}-repositories";
            description = "Initialize the ${name} borg repository if not already a repository";
            path = with pkgs; [ borgbackup openssh ];
            script = let
              initRepoIfNotInitialized = repo: ''
                ${borgLib.setEnv repo}
                set +e
                borg info ${borgLib.buildPath repo}
                if [ $? -eq 2 ]; then
                  borg init -e${repo.encryption.mode} ${borgLib.buildPath repo}
                fi

                '';
            in ''
                ${optionalString cfg.database.enable (initRepoIfNotInitialized cfg.database.repository)}
                ${optionalString cfg.directories.enable (initRepoIfNotInitialized cfg.directories.repository)}
            '';
          })
        ])

        (mkAfter [
          (mkIf (cfg.restore && cfg.directories.enable) {
            name = "restore-${name}-directories-backup";
            description = "Restore the latest ${name} directories backup";
            path = with pkgs; [ borgbackup openssh rsync ];
            script = let 
              repo = cfg.directories.repository;
              paths = concatStringsSep " " (map (path: ''"${toString path}"'') cfg.directories.paths);
            in ''
              set -x
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
        ])

        (mkAfter [
          (mkIf (cfg.restore && cfg.database.enable) {
            name = "restore-${name}-database-backup";
            description = "Restore the latest ${name} database backup";
            path = with pkgs; [ borgbackup openssh ];
            script = let repo = cfg.database.repository; in
            ''
              ${borgLib.setEnv repo}
              if ${borgLib.repoNotEmpty repo}; then
                latest_archive=$(borg list --last 1 --format '{archive}' ${borgLib.buildPath repo})
                ${myLib.db.runSqlAsRoot "$(borg extract --stdout ${borgLib.buildPath repo}::$latest_archive)"}
              fi
            '';
            user = "root";
          })
        ])
      ];

      systemd = {
        tmpfiles.rules = [
          (mkIf (cfg.database.enable && cfg.database.repository.localPath != null) "d ${cfg.database.repository.localPath} 700 ${cfg.user} ${cfg.user} - -")
          (mkIf (cfg.directories.enable && cfg.directories.repository.localPath != null) "d ${cfg.directories.repository.localPath} 700 ${cfg.user} ${cfg.user} - -")
        ];

        timers = {
          "backup-${name}-database" = mkIf cfg.database.enable {
            wantedBy = [ "timers.target" ];

            partOf = [ "backup-${name}-database.service" ];

            # TODO: programmable backup frequency
            timerConfig.OnCalendar = "daily";
          };

          "backup-${name}-directories" = mkIf cfg.directories.enable {
            wantedBy = [ "timers.target" ];

            partOf = [ "backup-${name}-directories.service" ];

            timerConfig.OnCalendar = "daily";
          };
        };

        services = {
          "backup-${name}-database" = mkIf cfg.database.enable {
            description = "Make a backup of the ${name} database";

            path = with pkgs; [ config.services.mysql.package borgbackup openssh ];

            script = let repo = cfg.database.repository; in
            ''
              ${borgLib.setEnv repo}
              mysqldump --order-by-primary ${myLib.db.authentication dbCfg} --databases ${dbCfg.name} --add-drop-database | borg create ${borgLib.buildPath repo}::{now} -
            '';

            serviceConfig = {
              Type = "oneshot";
              User = cfg.user;
            };
          };

          "backup-${name}-directories" = mkIf cfg.directories.enable {
            description = "Make a backup of the ${name} directories";

            path = with pkgs; [ borgbackup openssh ];

            script = let repo = cfg.directories.repository; in ''
              ${borgLib.setEnv repo}
              borg create ${borgLib.buildPath repo}::{now} ${concatStringsSep " " (map (path: ''"${path}"'') cfg.directories.paths)}
            '';

            serviceConfig = {
              Type = "oneshot";
              User = cfg.user;
            };
          };
        };
      };
    };
  }
