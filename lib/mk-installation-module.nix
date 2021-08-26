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

        group = mkOption {
          type = str;
          default = cfg.user;
          description = "Default group of the user";
        };

        ports = mkOption {
          type = attrsOf int;
          default = {
            # TODO: A bit dangerous? this could mean that any client that uses this module
            # will have 80 open if it does not override the option. Check if overrides delete any contents
            http = if (hasAttr "ssl" config.machines.${name} && config.machines.${name}.ssl.enable) then 443 else 80; 
          };
          description = "Name of protocol to port that will be open/served by the application";
        };
      };
    };

    config = {
      networking.firewall.allowedTCPPorts = mapAttrsToList (name: value: value) cfg.ports;

      systemd.tmpfiles.rules = [ "d ${cfg.path} - ${cfg.user} ${cfg.group} - -" ];

      users = {
        users.${cfg.user} = {
          isSystemUser = mkDefault true;
          home = cfg.path;
          group = cfg.user;
          extraGroups = [ "keys" cfg.group ]; # needed for nixops, to access /run/keys
        };

        groups = mkMerge [
          { ${cfg.group} = {}; } # create the group
          (mkIf (cfg.group != cfg.user) { ${cfg.user} = {}; }) # create a group with user's name
        ];
      };
    };
  }
