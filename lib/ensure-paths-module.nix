{ config, lib, ... }:
with lib;
let
  defaultPermissions = null; # Inherit from ACL
  defaultOwner = "root";

  pathModule = types.submodule {
    options = with types; {
      path = mkOption {
        type = str;
        description = "Path to ensure";
      };

      permissions = mkOption {
        type = nullOr str;
        default = defaultPermissions;
        description = "Permissions to ensure on path";
      };

      owner = mkOption {
        type = str;
        default = defaultOwner;
        description = "Owner of path";
      };
    };
  };

  convertToPathModule = obj: if ((builtins.typeOf obj) == "string") then {
    path = obj;
    permissions = defaultPermissions;
    owner = defaultOwner;
  } else obj;

  paths = map (convertToPathModule) config.services.ensurePaths;
in {
  options = {
    services.ensurePaths = with types; mkOption {
      type = listOf (oneOf [str pathModule]);
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
