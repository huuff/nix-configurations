name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.${name};
in
  {
    options = {
      services.${name}.ssl = with types; {

        enable = mkEnableOption "Whether to auto-generate an SSL certificate";

        path = mkOption {
          type = oneOf [ path str ];
          default = "/var/ssl/";
          description = "Path of the generated certificate";
        };
      };
    };

    config = {
      
      systemd.services."create-${name}-cert" = {
        description = "Create a certificate for ${name}";

        script = ''
          ${pkgs.libressl}/bin/openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost'
        '';

        wantedBy = [ "nginx.service" ];
        
        unitConfig = {
          Before = [ "nginx.service"];
        };

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
  }
