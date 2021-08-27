name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.machines.${name}.database;
  myLib = import ./default.nix { inherit config pkgs lib; };
in
  {
    options = with types; {
      machines.${name} = {
        database = {
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
            default = config.machines.${name}.installation.user or name;
            description = "Name of the database user";
          };

          authenticationMethod = mkOption {
            type = enum [ "socket" "password" ];
            default = "socket";
            description = "What to authenticate the user to the DB with";
          };

          passwordFile = mkOption {
            type = nullOr (oneOf [ str path ]);
            default = null;
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

    config = {
      assertions = [
        {
          assertion = (cfg.passwordFile != null) -> (cfg.authenticationMethod == "password");
          message = "The authenticationMethod must be 'password' to use passwordFile";
        }
        {
          assertion = (cfg.authenticationMethod == "password") -> (cfg.passwordFile != null);
          message = "If authenticationMethod is 'password', then passwordFile must be set";
        }
        {
          assertion = (cfg.authenticationMethod == "socket") -> (hasAttr cfg.user config.users.users);
          message = "For DB socket authentication, the system user ${cfg.user} must exist!";
        }
        {
          assertion = (config.machines.${name} ? installation) -> (cfg.user == config.machines.${name}.installation.user);
          message = "If a machine has the 'installation' module, then installation.user must be the same as database.user!";
        }
      ];

      services.mysql = {
        enable = true;
        package = mkDefault pkgs.mariadb;
      };

      users.users.${cfg.user} = mkIf (config.machines.${name} ? installation) {
        isSystemUser = true;
      };

      systemd.services = {
        "setup-${name}-db" = {
          description = "Create ${cfg.name} and give ${cfg.user} permissions to it";

          script = myLib.db.runSqlAsRoot ''
            CREATE DATABASE IF NOT EXISTS ${cfg.name};
            CREATE USER IF NOT EXISTS '${cfg.user}'@${cfg.host} ${ if cfg.authenticationMethod == "password"
            then "IDENTIFIED BY '${myLib.passwd.cat cfg.passwordFile}'"
            else "IDENTIFIED VIA unix_socket"
            };
            GRANT ALL PRIVILEGES ON ${cfg.name}.* TO '${cfg.user}'@${cfg.host};
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
