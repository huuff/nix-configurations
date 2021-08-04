name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.${name}.ssl;
in
  {
    imports = [ ./ensure-paths-module.nix ];

    options = {
      services.${name}.ssl = with types; {

        enable = mkEnableOption "Whether to auto-generate an SSL certificate";

        user = mkOption {
          type = str;
          default = "root";
          description = "User that will own the certificate";
        };

        path = mkOption {
          type = oneOf [ path str ];
          default = "/var/ssl";
          description = "Path of the generated certificate";
        };
      };
    };

    config = mkIf cfg.enable {
      
      services.ensurePaths = [ { path = cfg.path; } ];

      systemd.services."create-${name}-cert" = {
        description = "Create a certificate for ${name}";

        script = ''
          ${pkgs.libressl}/bin/openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost'
        '';

        wantedBy = [ "multi-user.target" ] ++ optional config.services.nginx.enable "nginx.service";
        
        unitConfig = {
          Before = [ "multi-user.target"] ++ optional config.services.nginx.enable "nginx.service" ;
          After = [ "ensure-paths.service" ];
          Requires = [ "ensure-paths.service" ];
          ConditionPathExists = "!${cfg.path}/cert.pem";
        };

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          WorkingDirectory = cfg.path;
          RemainAfterExit = true;
        };
      };
    };
  }
