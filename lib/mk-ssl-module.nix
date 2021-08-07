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
          default = if (builtins.hasAttr "installation" config.services.${name}) then config.services.${name}.installation.user else "root";
          description = "User that will own the certificate";
        };

        path = mkOption {
          type = oneOf [ path str ];
          default = "/etc/ssl/${name}";
          description = "Path of the generated certificate";
        };

        httpsOnly = mkOption {
          type = bool;
          default = cfg.enable;
          description = "Whether to redirect all http traffic to https";
        };
      };
    };

    config = mkIf cfg.enable {

      networking.firewall.allowedTCPPorts = [ 443 ];

      services.nginx.virtualHosts.${name} = mkIf config.services.nginx.enable {
        addSSL = !cfg.httpsOnly;
        forceSSL = cfg.httpsOnly;
        sslCertificate = "${cfg.path}/cert.pem";
        sslCertificateKey = "${cfg.path}/key.pem";
      };
      
      services.ensurePaths = [ { 
        path = cfg.path;
        owner = cfg.user;
      } ];

      systemd.services."create-${name}-cert" = {
        description = "Create a certificate for ${name}";

        script = ''
          ${pkgs.libressl}/bin/openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj '/CN=localhost'
          chmod 644 cert.pem
          chmod 640 key.pem
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
