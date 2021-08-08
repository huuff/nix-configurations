name:
{ lib, config, ... }:
with lib;
let
  cfg = config.services.${name}.initialization;

  initModule = with types; submodule {
    options = {
      name = mkOption {
        type = str;
        description = "Name of the systemd unit";
      };

      description = mkOption {
        type = str;
        description = "Description of the unit";
      };

      user = mkOption {
        type = str;
        default = if (builtins.hasAttr "installation" config.services.${name}) then config.services.${name}.installation.user else null;
        description = "User that will run the unit";
      };

      script = mkOption {
        type = str;
        description = "Script that will be run";
      };
    };
  };

  initModuleToUnit = initModule: nameValuePait initModule.name {
      inherit script description;

      serviceConfig = {
        User = initModule.user;
        Type = "oneshot";
        RemainAfterExit = true;
      };
  };

  after = first: second: recursiveUpdate second {
    value.unitConfig = {
      After = [ "${first.name}.service" ];
      Requires = [ "${second.name}.service" ];
    };
  };

  foldl1 = f: list: foldl (head list) (tail list);

  # Make the last unit so that it's started automatically, thus propagating
  # to all the previous ones.
  mkLast = unit: recursiveUpdate unit {
    value.wantedBy = [ "multi-user.target" ];
  };
in  
  {
    options = {
      services.${name}.initialization = mkOption {
        type = (types) listOf initModule;
        default = [];
        description = "Each of the scripts to run for provisioning, in the required order";
      };
    };

    config = {
      systemd.services = 
      let
        unorderedUnits = map initModuleToUnit cfg;
        orderedUnits = foldl1 (after) unorderedUnits;
        autoStartedUnits = (init orderedUnits) ++ (mkLast (last orderedUnits));
      in listToAttrs autoStartedUnits;
    };
  }
