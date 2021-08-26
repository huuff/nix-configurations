# TODO: DRY this. e.g. some function that sets all environment variables
# TODO: Maybe passphrase from file descriptor? This might allow less eavesdropping
name:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.${name}.backup;
  dbCfg = if (hasAttr "database" config.machines.${name}) then config.machines.${name}.database else null;
  dbRepo = cfg.database.repository;

  allowUnencryptedRepo = repo: optionalString (repo.encryption.mode == "none") "export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes";
  exportPassphrase = repo: optionalString (repo.encryption.mode != "none") "export BORG_PASSPHRASE=${myLib.passwd.cat repo.encryption.passphraseFile}";
  setBorgRSH = repo: optionalString (repo.remote != null) "ssh -i ${repo.remote.key}";

  myLib = import ../../lib/default.nix { inherit config pkgs lib; };

  buildPath = repo: if (repo.path != null) then repo.path else "ssh://${repo.remote.user}@${repo.remote.hostname}:${repo.remote.path}";

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

  repoNotEmpty = repo: "[ $(borg list ${buildPath repo} | wc -l) -ne 0 ]";

  repository = with types; submodule {
    options = { 
      # TODO: Something like `localPath`?
      path = mkOption {
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
          default = if hasAttr "installation" config.machines.${name} then config.machines.${name}.installation.user else null;
          description = "User that will run the backup script";
        };

        directories = {
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
          assertion = ((cfg.database.repository.path != null) -> cfg.database.repository.remote == null) && ((cfg.directories.repository.path != null) -> cfg.directories.repository.remote == null);
          message = "You can't set a path and a remote at the same time for a repository!";
        }
      ];

      machines.${name}.initialization.units = mkMerge [ 
        (mkBefore [
          (mkIf (cfg.database.enable || cfg.directories.enable) {
            name = "initialize-${name}-repositories";
            description = "Initialize the ${name} borg repository if not already a repository";
            path = [ pkgs.borgbackup ];
            script = let
              initRepoIfNotInitialized = repo: ''
                ${allowUnencryptedRepo repo}
                ${exportPassphrase repo}
                ${setBorgRSH repo}
                set +e
                borg info ${buildPath repo}
                if [ $? -eq 2 ]; then
                  borg init -e${repo.encryption.mode} ${buildPath repo}
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
            path = [ pkgs.borgbackup ];
            script = ''
              ${allowUnencryptedRepo dbRepo}
              ${exportPassphrase dbRepo}
              ${setBorgRSH dbRepo}
              if ${repoNotEmpty cfg.directories.repository}; then
                latest_archive=$(borg list --last 1 --format '{archive}' ${buildPath cfg.database.repository})
              else
                exit 0
              fi

              for path_to_backup in ${concatStringsSep " " (map (path: ''"${toString path}"'') cfg.directories.paths)}
              do
                cd "$path_to_backup" && rm -rf * && borg extract ${buildPath cfg.directories.repository}::$latest_archive $(basename "$path_to_backup")
              done
            '';
            user = "root";
          })
        ])

        # TODO: This is AFTER finish, should be just before. mkOrder?
        (mkAfter [
          (mkIf (cfg.restore && cfg.database.enable) {
            name = "restore-${name}-database-backup";
            description = "Restore the latest ${name} database backup";
            path = [ pkgs.borgbackup ];
            script = ''
              ${allowUnencryptedRepo dbRepo}
              ${exportPassphrase dbRepo}
              ${setBorgRSH dbRepo}
              if ${repoNotEmpty cfg.database.repository}; then
                latest_archive=$(borg list --last 1 --format '{archive}' ${buildPath cfg.database.repository})
                ${myLib.db.runSqlAsRoot "$(borg extract --stdout ${buildPath cfg.database.repository}::$latest_archive)"}
              fi
            '';
            user = "root";
          })
        ])
      ];

      systemd = {
        # TODO: Create only if remote, check if perms are right
        tmpfiles.rules = mkIf cfg.database.enable [
          (optionalString (cfg.database.enable && cfg.database.repository.path != null) "d ${cfg.database.repository.path} 755 ${cfg.user} ${cfg.user} - -")
          (optionalString (cfg.directories.enable && cfg.directories.repository.path != null) "d ${cfg.directories.repository.path} 755 ${cfg.user} ${cfg.user} - -")
        ];

        timers = {
          "backup-${name}-database" = mkIf cfg.database.enable {
            wantedBy = [ "timers.target" ];

            partOf = [ "backup-${name}-database.service" ];

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

            path = [ config.services.mysql.package  pkgs.borgbackup ];

            script = let
              authentication = if (dbCfg.authenticationMethod == "password") then "-p ${myLib.passwd.cat dbCfg.passwordFile}" else "";
            in
            ''
              ${allowUnencryptedRepo dbRepo}
              ${exportPassphrase dbRepo}
              ${setBorgRSH dbRepo}
              mysqldump --order-by-primary -u${dbCfg.user} ${authentication} --databases ${dbCfg.name} --add-drop-database | borg create ${buildPath cfg.database.repository}::{now} -
            '';

            serviceConfig = {
              Type = "oneshot";
              User = cfg.user;
            };
          };

          "backup-${name}-directories" = mkIf cfg.directories.enable {
            description = "Make a backup of the ${name} directories";

            path = [ pkgs.borgbackup ];

            script = ''
              ${allowUnencryptedRepo dbRepo}
              ${exportPassphrase dbRepo}
              ${setBorgRSH dbRepo}
              borg create ${buildPath cfg.directories.repository}::{now} ${concatStringsSep " " (map (path: ''"${path}"'') cfg.directories.paths)}
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
