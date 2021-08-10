{ config, pkgs, lib, ... }:
with lib;

{
  options = with types; {
    services.mail = {
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
