name:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.${name};

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
        default = "/var/backup/${name}";
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
          default = if hasAttr "installatio" config.machines.${name} then config.machines.${name}.installation else null;
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
      };
    };

    config = {
      assertions = [
        {
          assertion = cfg.backup.database.enable -> cfg.database.enable;
          message = "Can't enable database backup without enabling database!";
        }
      ];

      systemd = {
        tmpfiles.rules = mkIf cfg.database.enable [
          "d ${cfg.backup.database.path} 0644 ${cfg.installation.user} ${cfg.installation.user} - -"
        ];

        timers = {
          "backup-${name}-database" = mkIf cfg.backup.database.enable {
            wantedBy = [ "timers.target" ];

            partOf = [ "backup-${name}-database.service" ];

            timerConfig.OnCalendar = "daily";
          };
        };

        services = {
          "backup-${name}-database" = mkIf cfg.backup.database.enable {
            description = "Make a backup of the ${name} database";

            path = [ config.services.mysql.package ];

            script = ''
              mysqldump --order-by-primary -u ${cfg.database.user} -p${myLib.passwd.cat cfg.database.passwordFile} ${cfg.database.name} > ${cfg.backup.database.path}/dump.sql
            '';

            serviceConfig.Type = "oneshot";
          };
        };
      };
    };
  }
