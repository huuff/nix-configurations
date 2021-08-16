name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.machines.${name}.installation;
in
  {
    options = {
      machines.${name}.installation = with types; {

        user = mkOption {
          type = str;
          default = name;
          description = "User on which ${name} will run";
        };

        path = mkOption {
          type = oneOf [ path str ];
          default = "/var/lib/${name}";
          description = "Path of the installation";
        };
      };
    };

    config = {
      systemd.tmpfiles.rules = [ "d ${cfg.path} - ${cfg.user} ${cfg.user} - -" ];

      users = {
        users.${cfg.user} = {
          isSystemUser = mkDefault true;
          home = cfg.path;
          group = cfg.user;
          extraGroups = [ "keys" ]; # needed for nixops, to access /run/keys
        };

        groups.${cfg.user} = {}; # create the group
      };
    };
  }
