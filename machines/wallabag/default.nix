{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wallabag;
  mkDatabaseModule = import ../../lib/mkDatabaseModule.nix;
  myLib = import ../../lib/default.nix { inherit config lib; };
  phpWithTidy = pkgs.php74.withExtensions ( { enabled, all }: enabled ++ [ all.tidy ] );
in
  {

    imports = [
      (mkDatabaseModule "wallabag")
    ];

    options.services.wallabag = with types; {
      enable = mkEnableOption "Whether to enable the wallabag service";

      package = mkOption {
        type = package;
        default = pkgs.wallabag;
        description = "The wallabag package to use";
      };

      user = mkOption {
        type = str;
        default = "wallabag";
        description = "User under which to run wallabag";
      };

      directory = mkOption {
        type = oneOf [ path str ];
        default = "/var/lib/wallabag";
        description = "Path of the wallabag installation";
      };

    };

    config = mkIf cfg.enable {
      # TODO: Remove these, it's just for testing
      environment.systemPackages = with pkgs; [
        phpWithTidy
        (php74Packages.composer.override { php = phpWithTidy; })
        gnumake
        bash
      ];

      systemd.services = {

      # I wanted to copy and install in the same unit but copying is too expensive
      # because it comes with like one trillion files, so just copy in this unit and
      # install in another one so I can only run install while I test it
      copy-wallabag = {
        description = "Copy wallabag to final directory and setting permissions for installation";

        script = ''
          echo '>>> Copying all wallabag files from the store to ${cfg.directory}'
          cp -r ${cfg.package}/* ${cfg.directory}
          echo '>>> Setting write permissions to ${cfg.directory}'
          chmod -R u+w ${cfg.directory}
        '';

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          WorkingDirectory = cfg.directory;
          RemainAfterExit = true;
        };

        unitConfig.ConditionDirectoryNotEmpty = "!${cfg.directory}";
      };

      create-parameters = {
        description = "Create parameters.yml for installation";

        script =
        let 
          dbName = cfg.database.name;
          dbUser = cfg.database.user;
          dbPrefix = cfg.database.prefix;
          dbPasswordFile = toString cfg.database.passwordFile;
          openssl = "${pkgs.libressl}/bin/openssl";
          parameters = builtins.readFile (pkgs.substituteAll {
            src = ./parameters_template.yml;
            inherit dbName dbUser dbPrefix dbPasswordFile openssl;
          });
        in
        ''
          rm ${cfg.directory}/app/config/parameters.yml
          echo "${parameters}" >> ${cfg.directory}/app/config/parameters.yml
        '';

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          RemainAfterExit = true;
        };

        unitConfig = {
          After = [ "copy-wallabag.service" ];
          Requires = [ "copy-wallabag.service"];
        };
      };

      install-wallabag = {
        description = "Install wallabag";

        script = ''
          set -x
          make clean
          make install
        ''; 

        wantedBy = [ "multi-user.target" ];

        path = with pkgs; [ 
          gnumake
          bash
          (php74Packages.composer.override { php = phpWithTidy; })
          phpWithTidy
        ];

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          WorkingDirectory = cfg.directory;
          RemainAfterExit = true;
        };

        unitConfig = {
          After = [ "create-parameters.service" "setup-wallabag-db.service" ];
          Requires = [ "create-parameters.service" "setup-wallabag-db.service" ];
        };
      };
    };

    users.users.${cfg.user} = {
      #isSystemUser = true;
      isNormalUser = true; # TODO: Go back to isSystemUser, I'm using this only for testing
      home = cfg.directory;
      group = cfg.user;
      extraGroups = [ "keys" ];
      createHome = true;
    };

    users.groups.${cfg.user} = {};
  };
}
