{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.machines.mail;
in
{
  options = with types; {
    machines.mail = {
      enable = mkEnableOption "Whether to enable a full email server"; 


    };
  };

  config = mkIf cfg.enable {

    services = {
      dovecot2 = {
        enable = true;
      };

      postfix = {
        enable = true;
      };
    };
  };
}
