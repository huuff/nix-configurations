name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.${name}.user;
in
  {
    imports = [ ./ensure-paths-module.nix ];

    options = {
      services.${name}.user = with types; {

        name = mkOption {
          type = str;
          default = name;
          description = "User on which ${name} will run";
        };

        home = mkOption {
          type = oneOf [ path str ];
          default = "/var/lib/${name}";
          description = "Home of the user";
        };
      };
    };

    config = {
      services.ensurePaths = [ cfg.home ];

      users = {
        users.${cfg.name} = {
          isSystemUser = true;
          home = cfg.home;
          group = cfg.name;
          extraGroups = [ "keys" ]; # needed for nixops, to access /run/keys
        };

        groups.${cfg.name} = {}; # create the group
      };
    };
  }
