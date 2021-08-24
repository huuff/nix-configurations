name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.machines.${name}.ssl;
  sslPath = "/etc/ssl";
  certPath = "${sslPath}/certs/${name}.pem";
  keyPath = "${sslPath}/private/${name}.pem";
in
  {
    options = {
      machines.${name}.ssl = with types; {

        enable = mkEnableOption "SSL certificate";

        autoGenerate = mkOption {
          type = bool;
          default = true;
          description = "Whether to auto-generate an SSL certificate for ${name}";
        };

        certificate = mkOption {
          type = nullOr (oneOf [ str path ]);
          default = null;
          description = "Path to the certificate";
        };

        key = mkOption {
          type = nullOr (oneOf [ str path ]);
          default = null;
          description = "Path of the certificate key";
        };

        user = mkOption {
          type = str;
          default = if (builtins.hasAttr "installation" config.machines.${name}) then config.machines.${name}.installation.user else "root";
          description = "User that will own the certificate";
        };

        httpsOnly = mkOption {
          type = bool;
          default = cfg.enable;
          description = "Whether to redirect all http traffic to https";
        };
      };
    };

    config = mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.autoGenerate -> (cfg.certificate == null && cfg.key == null);
          message = "If ssl.autoGenerate is activated, you can't supply certificate nor key!";
        }
      ];

      networking.firewall.allowedTCPPorts = [ 443 ];

      services.nginx.virtualHosts.${name} = mkIf (config.services.nginx.enable && cfg.enable) {
        addSSL = !cfg.httpsOnly;
        forceSSL = cfg.httpsOnly;
        sslCertificate = certPath;
        sslCertificateKey = keyPath;
      };
      
      systemd.tmpfiles.rules = 
      [
        "d ${sslPath}/certs 755 root root - - "
        "d ${sslPath}/private 755 root root - - "
      ];

      systemd.services."setup-${name}-cert" = mkIf cfg.enable {
        description = "Create a certificate for ${name}";

        # For provided cert, maybe softlink instead of copying? but I don't want to need
        # to have the cert around as provided by some deploy tool
        script = (if cfg.autoGenerate
        then ''
          ${pkgs.libressl}/bin/openssl req -x509 -newkey rsa:4096 -keyout ${keyPath} -out ${certPath} -days 365 -nodes -subj '/CN=localhost'
        ''
        else ''
          cp ${cfg.certificate} ${certPath}
          cp ${cfg.key} ${keyPath}
        '') + ''
          chown ${cfg.user}:${cfg.user} ${certPath}
          chown ${cfg.user}:${cfg.user} ${keyPath}
          chmod 644 ${certPath}
          chmod 640 ${keyPath}
          ''
        ;

        wantedBy = [ "multi-user.target" ] ++ optional config.services.nginx.enable "nginx.service";
        
        unitConfig = {
          Before = [ "multi-user.target"] ++ optional config.services.nginx.enable "nginx.service" ;
          ConditionPathExists = "!${certPath}";
        };

        serviceConfig = {
          User = "root";
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
  }
