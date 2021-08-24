name:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.${name}.backup;
  dbCfg = if (hasAttr "database" config.machines.${name}) then config.machines.${name}.database else null;
  dbRepo = cfg.database.repository;

  allowUnencryptedRepo = repo: if (repo.encryption.mode == "none") then "export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes" else "";
  exportPassphrase = repo: if (repo.encryption.mode != "none") then "export BORG_PASSPHRASE=${myLib.passwd.cat repo.encryption.passphraseFile}" else "";

  myLib = import ./default.nix { inherit config pkgs; };

  remote = with types; submodule {
    options = {
      user = mkOption {
        type = str;
        default = null;
        description = "User that will be used to connect through SSH to the repository";
      };

      key = mkOption {
        type = oneOf [ path str ];
        default = null;
        description = "Path of the key used to connect through ssh to the repository";
      };
    };
  };

  repoNotEmpty = repoPath: "[ $(borg list ${repoPath} | wc -l) -ne 0 ]";

  repository = with types; submodule {
    options = { 
      path = mkOption {
        type = oneOf [ str path ];
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

        database = {
          enable = mkEnableOption "database module backup";

          repository = mkOption {
            type = repository;
            default = {};
            description = "Options for the borg repository where the backup will be stored";
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
          assertion = cfg.database.enable -> cfg.database.enable;
          message = "Can't enable database backup without enabling database!";
        }
      ];

      machines.${name}.initialization.units = mkMerge [ 
        (mkBefore [
          (mkIf cfg.database.enable {
            name = "initialize-${name}-repository";
            description = "Initialize the ${name} borg repository if not already a repository";
            path = [ pkgs.borgbackup ];
            script = ''
              ${allowUnencryptedRepo dbRepo}
              ${exportPassphrase dbRepo}
              set +e
              borg info ${dbRepo.path}
              if [ $? -eq 2 ]; then
                borg init -e${dbRepo.encryption.mode} ${dbRepo.path}
              fi
            '';
          })
        ])

        # TODO: This is AFTER finish, should be just before
        (mkAfter [
          (mkIf cfg.restore {
            name = "restore-${name}-backup";
            description = "Restore the latest ${name} backup";
            path = [ pkgs.borgbackup ];
            script = ''
              ${allowUnencryptedRepo dbRepo}
              ${exportPassphrase dbRepo}
              if ${repoNotEmpty cfg.database.repository.path}; then
                latest_archive=$(borg list --last 1 --format '{archive}' ${cfg.database.repository.path})
                ${myLib.db.runSqlAsRoot "$(borg extract --stdout ${cfg.database.repository.path}::$latest_archive)"}
              fi
            '';
            user = "root";
            extraDeps = [ "mysql.service" ];
          })
        ])
      ];

      systemd = {
        tmpfiles.rules = mkIf cfg.database.enable [
          "d ${cfg.database.repository.path} 755 ${cfg.user} ${cfg.user} - -"
        ];

        timers = {
          "backup-${name}-database" = mkIf cfg.database.enable {
            wantedBy = [ "timers.target" ];

            partOf = [ "backup-${name}-database.service" ];

            timerConfig.OnCalendar = "daily";
          };
        };

        services = {
          "backup-${name}-database" = mkIf cfg.database.enable {
            description = "Make a backup of the ${name} database";

            environment.BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = "yes";

            path = [ config.services.mysql.package  pkgs.borgbackup ];

            script = let
              authentication = if (dbCfg.authenticationMethod == "password") then "-p ${myLib.passwd.cat dbCfg.passwordFile}" else "";
            in
            ''
              ${allowUnencryptedRepo dbRepo}
              ${exportPassphrase dbRepo}
              mysqldump --order-by-primary -u${dbCfg.user} ${authentication} --databases ${dbCfg.name} --add-drop-database | borg create ${cfg.database.repository.path}::{now} -
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
