{ config, lib, ... }:
with lib;
let
  paths = config.services.ensurePaths;
  pathModule = types.submodule {
    options = with types; {
      path = mkOption {
        type = str;
        description = "Path to ensure";
      };

      permissions = mkOption {
        type = nullOr str;
        default = null;
        description = "Permissions to ensure on path";
      };

      owner = mkOption {
        type = str;
        default = "root";
        description = "Owner of path";
      };
    };
  };
in {
  options = {
    services.ensurePaths = with types; mkOption {
      type = listOf pathModule;
      default = [];
      description = "Paths whose existence is to be guaranteed by multi-user.target";
    };
  };

  config = {
    systemd.services.ensure-paths = {
      description = "Ensure some paths exist on boot";

      script = let
         pathScript = path: ''
           mkdir -p ${path.path}
           ${optionalString (!isNull path.permissions) "chmod ${path.permissions} ${path.path}"}
           chown ${path.owner}:${path.owner} ${path.path}
         '';
      in concatStringsSep "\n" (map (pathScript) paths);

      wantedBy =[ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      unitConfig = {
        ConditionPathExists = map (path: "|!${path.path}") paths;
      };
    };
  };
}
