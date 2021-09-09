{ config, lib, ... }:

with lib;

let
  cfg = config.multi-deploy;
  machineCfg = machineName: config.machines.${machineName};
in
{
  options = {
    multi-deploy = with types; {
      group = mkOption {
        type = nullOr str;
        default = null;
        description = "Group that all machine users will be on";
      };
    };
  };

  config =
  let
    machines = mapAttrsToList (machineName: machineCfg: machineName) config.machines;
    machinesWithInstallation = filter (machine: (machineCfg machine) ? installation) machines;
    portsByMachine = map (machine: mapAttrsToList (protocol: port: port) config.machines.${machine}.installation.ports) machinesWithInstallation;
    usedPorts = flatten portsByMachine;
    getConflictingPorts = list:
      if list == [] then []
      else 
        if (builtins.elem (head list) (tail list)) 
          then [(head list)] ++ getConflictingPorts (tail list) 
          else [] ++ getConflictingPorts (tail list)
        ;
      conflictingPorts = getConflictingPorts usedPorts;
  in mkMerge [
    { assertions = [
      {
        assertion = conflictingPorts == [];
        message = "These ports are being used by more than one machine: ${toString conflictingPorts}";
      }
    ]; }

    (mkIf (cfg.group != null) {
      machines = listToAttrs (map (machine: {
        name = machine;
        value = { installation.group = cfg.group; };
      }) machinesWithInstallation);
    })
  ];
}
