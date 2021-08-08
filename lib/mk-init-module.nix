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
        default = if (builtins.hasAttr "installation" config.services.${name}) then config.services.${name}.installation.user else "root";
        description = "User that will run the unit";
      };

      script = mkOption {
        type = str;
        description = "Script that will be run";
      };
    };
  };

  initModuleToUnit = initModule: nameValuePair initModule.name {
    script = initModule.script;
    description = initModule.description;

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

  foldl1 = f: list: foldl f (head list) (tail list);

  orderUnits = let
    orderUnitsAux = current: alreadyOrdered: unorderedYet: 
      if unorderedYet == []
      then alreadyOrdered
      else
        let
          nextCurrent = head unorderedYet;
        in
          orderUnitsAux (nextCurrent) (alreadyOrdered ++ [(after current nextCurrent)]) (tail unorderedYet);
    in units: orderUnitsAux (head units) [(head units)] (tail units);

  # Make the last unit so that it's started automatically, thus propagating
  # to all the previous ones.
  mkLast = unit: recursiveUpdate unit {
    value.wantedBy = [ "multi-user.target" ];
  };
in  
  {
    options = {
      services.${name}.initialization = mkOption {
        type = types.listOf initModule;
        default = [];
        description = "Each of the scripts to run for provisioning, in the required order";
      };
    };

    config = {
      systemd.services = 
      let
        unorderedUnits = traceVal (map initModuleToUnit cfg);
        orderedUnits = traceVal (orderUnits (unorderedUnits));
        autoStartedUnits = (init orderedUnits) ++ [(mkLast (last orderedUnits))];
      in listToAttrs autoStartedUnits;
    };
  }
