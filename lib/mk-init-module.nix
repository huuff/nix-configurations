# TODO: DRY each unit
machineName:
{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.machines.${machineName}.initialization;

  lockPath = "/etc/inits/${machineName}"; # Path where locks will be put

  createLock = lockName: "${pkgs.coreutils}/bin/touch ${lockPath}/${lockName}";

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

      path = mkOption {
        type = listOf package;
        default = [];
        description = "Packages to add to the path of the unit";
      };

      extraDeps = mkOption {
        type = listOf str;
        default = [];
        description = "Services that are also dependencies of the unit";
      };

      user = mkOption {
        type = str;
        default = cfg.user;
        description = "User that will run the unit";
      };

      script = mkOption {
        type = str;
        description = "Script that will be run";
      };
    };
  };

  initModuleToUnit = initModule: nameValuePair initModule.name rec {
    script = initModule.script;
    description = initModule.description;
    path = initModule.path;

    serviceConfig = {
      User = initModule.user;
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = mkIf (hasAttr "installation" config.machines.${machineName}) config.machines.${machineName}.installation.path;
      ExecStartPost = createLock initModule.name;
    };

    unitConfig = {
      After = initModule.extraDeps;
      BindsTo = initModule.extraDeps;
      Requires = [];
      ConditionPathExists = "!${lockPath}/${initModule.name}";
    };
  };

  after = first: second: recursiveUpdate second {
    value.unitConfig = {
      After = [ "${first.name}.service" ] ++ second.value.unitConfig.After;
      Requires = [ "${first.name}.service" ] ++ second.value.unitConfig.Requires;
    };
  };

  # This creates a unit that is required by all others, running only if the "lock" does not exist
  # Therefore, if the "lock" exists (which means the initialization is complete) then nothing will run
  firstUnit = rec {
    name = "start-${machineName}-initialization";

    value = {
      description = "Start the provisioning of ${machineName}";

      script = "echo 'Start provisioning ${machineName}'";

      serviceConfig = {
        User = cfg.user;
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPost = createLock name;
      };

      unitConfig = {
        ConditionPathExists = "!${lockPath}/${name}"; 
      };

    };
  };

  # This creates a new unit that satisfies the following:
  # * Is after and requires all units in init.
  # * Is wanted by multi-user target, so it will be auto-started and propagate to all others.
  # * It creates a file that will signify the end of the initialization (the "lock")
  lastUnit = rec {
    name = "finish-${machineName}-initialization";

    value = {
      description = "Finish the provisioning of ${machineName}";
      script = "echo 'Finished provisioning ${machineName}'";

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = cfg.user;
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPost = createLock name;
      };

      # Just so after function works
      unitConfig = {
        After = [];
        Requires = [];
        ConditionPathExists = "!${lockPath}/${name}"; 
      };
    };
  };

  # Aux function for orderUnits
  orderUnitsRec = current: alreadyOrdered: unorderedYet: 
  if (length unorderedYet) == 0
  then
    alreadyOrdered ++ [ (after current lastUnit) ]
  else let 
    next = head unorderedYet;
    nextAfterCurrent = after current next;
    rest = tail unorderedYet;
  in
    orderUnitsRec next (alreadyOrdered ++ [nextAfterCurrent]) rest;

  # Orders units (sets after and binds to for each one to be after the other), adds first and last units
  orderUnits = units: orderUnitsRec (firstUnit) [firstUnit] (units);

in  
  {
    options = {
      machines.${machineName}.initialization = {
        user = mkOption {
          type = types.str;
          default = if (hasAttr "installation" config.machines.${machineName}) then config.machines.${machineName}.installation.user else "root";
          description = "Default user for the initialization units";
        };

        units = mkOption {
          type = types.listOf initModule;
          default = [];
          description = "Each of the scripts to run for provisioning, in the required order";
        };
      };
  };

    config = {

      systemd.tmpfiles.rules = [
        "d ${lockPath} - ${cfg.user} ${cfg.user} - -"
      ];

      systemd.services = 
      let
        unorderedUnits = map initModuleToUnit cfg.units;
        orderedUnits = orderUnits unorderedUnits;
      in (listToAttrs orderedUnits);
    };
  }
