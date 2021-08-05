name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.${name}.installation;
in
  {
    imports = [ ./ensure-paths-module.nix ];

    options = {
      services.${name}.installation = with types; {

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
      services.ensurePaths = [ { path = cfg.path; owner = cfg.user;} ];

      users = {
        users.${cfg.user} = {
          isNormalUser = true;
          home = cfg.path;
          group = cfg.user;
          extraGroups = [ "keys" ]; # needed for nixops, to access /run/keys
        };

        groups.${cfg.user} = {}; # create the group
      };
    };
  }
