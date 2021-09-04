{ config, lib, ... }:

with lib;

# TODO: Show the conflicting ports
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
    allDifferent = list:
      if list == [] then true
      else (!builtins.elem (head list) (tail list)) && (allDifferent (tail list))
    ;
  in mkMerge [
    { assertions = [
      {
        assertion = allDifferent usedPorts;
        message = "Some machines are using the same ports!";
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
