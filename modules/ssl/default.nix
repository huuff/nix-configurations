# XXX: Requires init module
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
          default = config.machines.${name}.installation.user or "root";
          description = "User that will own the certificate";
        };

        group = mkOption {
          type = str;
          default = config.machines.${name}.installation.group or "root";
          description = "Group that will own the certificate";
        };

        # TODO: Maybe should be sslOnly? This is going to be used for other ports other than http
        httpsOnly = mkOption {
          type = bool;
          default = false;
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

      machines.${name}.initialization.units = mkBefore [ (mkIf cfg.enable {
          name = "setup-${name}-cert";
          description = "Setup certificate for ${name}";
          path = [ pkgs.libressl ];
          user = "root";
          # For provided cert, maybe softlink instead of copying? but I don't want to need
          # to have the cert around as provided by some deploy tool
          script = ''
            rm -f ${certPath} ${keyPath} 
          '' + (if cfg.autoGenerate
          then ''
            openssl req -x509 -newkey rsa:4096 -keyout ${keyPath} -out ${certPath} -days 365 -nodes -subj '/CN=localhost'
          ''
          else ''
            cp ${cfg.certificate} ${certPath}
            cp ${cfg.key} ${keyPath}
          '') + ''
            chown ${cfg.user}:${cfg.group} ${certPath}
            chown ${cfg.user}:${cfg.group} ${keyPath}
            chmod 644 ${certPath}
            chmod 640 ${keyPath}
            '';
        })];

      systemd.services."setup-${name}-cert" = mkIf config.services.nginx.enable {
        wantedBy = [ "nginx.service" ];
        before = [ "nginx.service" ];
      };
    };
  }
