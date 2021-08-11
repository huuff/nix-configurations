{ config, pkgs, lib, ... }:
with lib;

{
  options = with types; {
    machines.mail = {
      enable = mkEnableOption "Whether to enable a full email server"; 


    };
  };

  config = {
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
