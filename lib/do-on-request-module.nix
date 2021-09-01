{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.do-on-request;
  myLib = import ./default.nix { inherit pkgs lib config; };
in
  {
    options.services.do-on-request = with types; {
      enable = mkEnableOption "do-on-request";

      port = mkOption {
        type = int;
        default = 12222;
        description = "Port on which to listen";
      };

      script = mkOption {
        type = str;
        description = "Script to run when a request is received";
      };

      directory = mkOption {
        type = nullOr str;
        default = null;
        description = "Path on which to run the script";
      };

      user = mkOption {
        type = nullOr str;
        default = null;
        description = "User which will run the service";
      };
    };

    config = mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = [ cfg.port ];

      systemd.services.do-on-request = myLib.mkHardenedUnit (optional (cfg.directory != null) cfg.directory) {
        description = "Run a script when a request is received on port ${toString cfg.port}";
        
        serviceConfig = {
          User = mkIf (cfg.user != null) cfg.user;
          Restart = "always";
          WorkingDirectory = mkIf (cfg.directory != null) cfg.directory;
        };

        script = ''
          #!${pkgs.stdenv.shell}
          set -x
          while true; do
            ${pkgs.netcat}/bin/nc -l ${toString cfg.port} | {
              ${cfg.script}
            }
          done
          '';

          wantedBy = [ "multi-user.target" ];
      };
    };

  }
