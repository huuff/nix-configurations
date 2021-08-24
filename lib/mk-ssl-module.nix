name:
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.machines.${name}.ssl;
  sslPath = "/etc/ssl";
  defaultCertPath = "${sslPath}/certs/${name}.pem";
  defaultKeyPath = "${sslPath}/private/${name}.pem";
  getCertPath = if (cfg.certificate != null) then cfg.certificate else defaultCertPath;
  getKeyPath = if (cfg.key != null) then cfg.key else defaultKeyPath;
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
        sslCertificate = getCertPath;
        sslCertificateKey = getKeyPath;
      };
      
      systemd.tmpfiles.rules = 
      [
        "d ${sslPath}/certs 755 root root - - "
        "d ${sslPath}/private 755 root root - - "
      ];

      systemd.services."create-${name}-cert" = mkIf cfg.autoGenerate {
        description = "Create a certificate for ${name}";

        script = ''
          ${pkgs.libressl}/bin/openssl req -x509 -newkey rsa:4096 -keyout ${getKeyPath} -out ${getCertPath} -days 365 -nodes -subj '/CN=localhost'
          chown ${cfg.user}:${cfg.user} ${getCertPath}
          chown ${cfg.user}:${cfg.user} ${getKeyPath}
          chmod 644 ${getCertPath}
          chmod 640 ${getKeyPath}
        '';

        wantedBy = [ "multi-user.target" ] ++ optional config.services.nginx.enable "nginx.service";
        
        unitConfig = {
          Before = [ "multi-user.target"] ++ optional config.services.nginx.enable "nginx.service" ;
          ConditionPathExists = "!${getCertPath}";
        };

        serviceConfig = {
          User = "root";
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
  }
