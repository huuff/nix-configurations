{ config, lib, ... }:

with lib;

# TODO: Show the conflicting ports
# TODO: Set all installations to a common group

{
  options = {};

  config =
  let
    machines = mapAttrsToList (machine: machineCfg: machineCfg) config.machines;
    machinesWithInstallation = filter (machine: machine ? installation) machines;
    portsByMachine = map (machine: mapAttrsToList (protocol: port: port) machine.installation.ports) machinesWithInstallation;
    usedPorts = flatten portsByMachine;
    allDifferent = list:
    if list == [] then true
    else (!builtins.elem (head list) (tail list)) && (allDifferent (tail list))
    ;
  in
  {
    assertions = [
      {
        assertion = allDifferent usedPorts;
        message = "Some machines are using the same ports!";
      }
    ];
  };
}
