name:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.${name};
  myLib = import ./default.nix { inherit config pkgs; };
in
  {
    options = with types; {
      machines.${name}.backup = {

        database = {
          enable = mkEnableOption "database module backup";

          path = mkOption {
            type = oneOf [ str path ];
            default = "/var/backup/${name}/db";
            description = "Path of the database dump";
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

            path = with pkgs; [ mariadb ];

            script = ''
              mysqldump --order-by-primary -u ${cfg.database.user} -p${myLib.passwd.cat cfg.database.passwordFile} ${cfg.database.name} > ${cfg.backup.database.path}/dump.sql
            '';

            serviceConfig.Type = "oneshot";
          };
        };
      };
    };
  }
