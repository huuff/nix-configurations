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
        description = "Services that are also dependencies of the unit. Added as `After` and `BindsTo`";
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

      idempotent = mkOption {
        type = bool;
        default = false;
        description = "This unit won't generate a 'lock' nor remain after exit and thus will be restarted on every activation";
      };
    };
  };

  mkUnit = { name, idempotent ? false }: unitConfig: { 
    inherit name;

    value = recursiveUpdate {
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        RemainAfterExit = mkIf (!idempotent) true;
        WorkingDirectory = mkIf (config.machines.${machineName} ? installation) config.machines.${machineName}.installation.path;
        ExecStartPost = mkIf (!idempotent) (createLock name);
      };

      unitConfig = {
        After = [];
        BindsTo = [];
        Requires = [];
        PartOf = [];
        ConditionPathExists = mkIf (!idempotent) "!${lockPath}/${name}";
      };

    } unitConfig;
  };

  initModuleToUnit = initModule: mkUnit { inherit (initModule) name idempotent; } {
    script = initModule.script;
    description = initModule.description;
    path = initModule.path;

    serviceConfig = {
      User = initModule.user;
    };

    unitConfig = {
      After = initModule.extraDeps;
      BindsTo = initModule.extraDeps;
    };
  };

  after = first: second: recursiveUpdate second {
    value.unitConfig = {
      After = [ "${first.name}.service" ] ++ second.value.unitConfig.After;
      Requires = [ "${first.name}.service" ] ++ second.value.unitConfig.Requires;
      PartOf = [ "${first.name}.service" ] ++ second.value.unitConfig.PartOf;
    };
  };

  # This creates a unit that is required by all others, running only if the "lock" does not exist
  # Therefore, if the "lock" exists (which means the initialization is complete) then nothing will run
  # This is useful as an "anchor point" for starting or restarting all units, since doing so with this one
  # will cascade to the rest
  firstUnit = mkUnit { name = "start-${machineName}-initialization"; } {
    description = "Start the provisioning of ${machineName}";

    script = "echo 'Start provisioning ${machineName}'";
  };

  # This creates a new unit that satisfies the following:
  # * Is after and requires all units in init.
  # * Is wanted by multi-user target, so it will be auto-started and propagate to all others.
  # * It creates a file that will signify the end of the initialization (the "lock")
  # This is useful for signaling, with a predictable name, that initialization is over
  lastUnit = mkUnit { name = "finish-${machineName}-initialization"; } {
    description = "Finish the provisioning of ${machineName}";
    script = "echo 'Finished provisioning ${machineName}'";

    wantedBy = [ "multi-user.target" ];
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
      machines.${machineName}.initialization = with types; {
        user = mkOption {
          type = str;
          default = config.machines.${machineName}.installation.user or "root";
          description = "Default user for the initialization units";
        };

        units = mkOption {
          type = listOf initModule;
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
