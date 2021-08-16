name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.machines.${name};
  myLib = import ./default.nix { inherit config pkgs; };
in
  {
    options = with types; {
      machines.${name} = {
        database = {
          enable = mkEnableOption "${name} database";

          host = mkOption {
            type = str;
            default = "localhost";
            description = "Host location of the database";
          };

          name = mkOption {
            type = str;
            default = name;
            description = "Name of the database";
          };

          user = mkOption {
            type = str;
            default = name;
            description = "Name of the database user";
          };

          passwordFile = mkOption {
            type = oneOf [ str path ];
            description = "Password of the database user";
          };

          prefix = mkOption {
            type = str;
            default = "${name}_";
            description = "Prefix to put on all tables of the database";
          };
        };
      };
    };

    config = mkIf cfg.database.enable {
      assertions = [
        {
          assertion = cfg.database.passwordFile != null;
          message = "database.passwordFile must be set";
        }
      ];

      services.mysql = {
        enable = true;
        package = mkDefault pkgs.mariadb;
      };

      systemd.services = {
        "setup-${name}-db" = {
          description = "Create ${cfg.database.name} and give ${cfg.database.user} permissions to it";

          script = myLib.db.execDDL ''
            CREATE DATABASE IF NOT EXISTS ${cfg.database.name};
            CREATE USER IF NOT EXISTS '${cfg.database.user}'@${cfg.database.host} IDENTIFIED BY '${myLib.passwd.cat cfg.database.passwordFile}';
            GRANT ALL PRIVILEGES ON ${cfg.database.name}.* TO '${cfg.database.user}'@${cfg.database.host};
          ''; 

          wantedBy = [ "multi-user.target" ];

          unitConfig = {
            After = [ "mysql.service" ];
            Requires = [ "mysql.service" ];
          };

          serviceConfig = {
            User = "root";
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      };
    };
  }
