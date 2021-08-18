{ lib, ... }:
machine: extraConf: { pkgs, config, lib, ... }:
  lib.recursiveUpdate (machine { inherit pkgs config lib; }) extraConf
