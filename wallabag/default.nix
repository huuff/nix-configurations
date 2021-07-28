{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wallabag;
in
{
  options.services.wallabag = with types; {
    enable = mkEnableOption "Whether to enable the wallabag service";

    package = mkOption {
      type = package;
      default = pkgs.wallabag;
      description = "The wallabag package to use";
    };

    user = mkOption {
      type = str;
      default = "wallabag";
      description = "User under which to run wallabag";
    };

    directory = mkOption {
      type = oneOf [ path str ];
      default = "/var/lib/wallabag";
      description = "Path of the wallabag installation";
    };
  };

  config = mkIf cfg.enable {

    # TODO: Ensure it's run only once
    systemd.services = {
      
      install-wallabag = {
        description = "Copy wallabag and run make install";

        script = ''
          set -x
          cp -rv ${cfg.package}/* ${cfg.directory}
          make install
        '';

        path = with pkgs; [ stdenv ];

        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          WorkingDirectory = cfg.directory;
          RemainAfterExit = true;
        };
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      home = cfg.directory;
      group = cfg.user;
      extraGroups = [ "keys" ];
      createHome = true;
    };

    users.groups.${cfg.user} = {};
  };
}
