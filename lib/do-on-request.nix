{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.do-on-request;
in
  {
    options.services.do-on-request = with types; {
      enable = mkEnableOption "Run something when receiving a request on some port";

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
        description = "User which will run the service";
      };
    };

    config = mkIf cfg.enable {
      systemd.services.do-on-request = {
        description = "Run a script when a request is received on port ${toString cfg.port}";
        
        serviceConfig = {
          User = mkIf (cfg.user != null) cfg.user;
          Restart = "always";
          WorkingDirectory = mkIf (cfg.directory != null) cfg.directory;
        };

        script = ''
          #!${pkgs.stdenv.shell}
          set -x
          while true;
          do {
            ${cfg.script}
          } | ${pkgs.netcat}/bin/nc -l ${toString cfg.port};
          done
          '';

          wantedBy = [ "multi-user.target" ];
          wants = [ "network.target" ];

          unitConfig = {
            After = [ "network.target" ];
          };
      };
    };

  }
