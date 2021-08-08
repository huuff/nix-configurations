name:
{ lib, config, ... }:
with lib;
let
  cfg = config.services.${name}.initialization;

  lockPath = "/etc/inits/${name}"; # Created when the initialization is finished

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
      BindsTo = [ "${first.name}.service" ];
    };
  };

  mkFirst = {
    name = "start-${name}-initialization";

    value = {
      description = "Start the provisioning of ${name}";

      script = "echo 'Start provisioning ${name}'";

      serviceConfig = {
        User = "root";
        Type = "oneshot";
        RemainAfterExit = true;
      };

      unitConfig = {
        ConditionPathExists = "!${lockPath}"; 
      };

    };
  };

  # This creates a new unit that satisfies the following:
  # * Is after and requires all units in init.
  # * Is wanted by multi-user target, so it will be auto-started and propagate to all others.
  # * It creates a file and runs only when it's not there. So it runs only once.
  mkLast = unit: after unit {
    name = "finish-${name}-initialization";

    value = {
      description = "Finish the provisioning of ${name}";
      script = ''
        mkdir -p /etc/inits
        touch ${lockPath}
        chmod 600 ${lockPath}
      '';

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "root";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };

  orderUnitsRec = current: alreadyOrdered: unorderedYet: 
  let 
    nextCurrent = head unorderedYet;
  in
      if (length unorderedYet) == 0
      then alreadyOrdered ++ [ (mkLast current) ]
      else orderUnitsRec (nextCurrent) (alreadyOrdered ++ [ (after current nextCurrent) ]) (tail unorderedYet);

  orderUnits = units: orderUnitsRec (mkFirst) [mkFirst] (units);

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
        unorderedUnits = map initModuleToUnit cfg;
        orderedUnits = orderUnits (unorderedUnits);
      in (listToAttrs orderedUnits);
    };
  }
