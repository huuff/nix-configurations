name:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.${name}.backup;

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
              set +e
              borg info ${cfg.database.repository.path}
              if [ $? -eq 2 ]; then
              borg init -e none ${cfg.database.repository.path}
              fi
            '';
          })
        ])

        (mkAfter [
          (mkIf cfg.restore {
            name = "restore-${name}-backup";
            description = "Restore the latest ${name} backup";
            path = [ pkgs.borgbackup ];
            script = ''
              ${myLib.runSqlAsRoot "DROP DATABASE ${cfg.database.name};"}
              latest_archive=$(borg list --last 1 --format '{archive}' ${cfg.database.repository.path})
              ${myLib.runSqlAsRoot "$(borg extract --stdout ${cfg.database.repository.path}::$latest_archive)"}
            '';
            user = "root";
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
              dbCfg = config.machines.${name}.database;
              authentication = if (dbCfg.authenticationMethod == "password") then "-p ${myLib.passwd.cat dbCfg.passwordFile}" else "";
            in
            ''
              mysqldump --order-by-primary -u${dbCfg.user} ${authentication} ${dbCfg.name} | borg create ${cfg.database.repository.path}::{now} -
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
