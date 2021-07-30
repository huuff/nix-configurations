{ myLib }:

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wallabag;
  phpWithTidy = pkgs.php74.withExtensions ( { enabled, all }: enabled ++ [ all.tidy ] );
in
  {
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

      database = {
        name = mkOption {
          type = str;
          default = "wallabag";
          description = "Name of the database for wallabag";
        };

        user = mkOption {
          type = str;
          default = "wallabag";
          description = "Name of the user for wallabag";
        };
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

      services.mysql = {
        enable = true;
        package = pkgs.mariadb;

        ensureDatabases = [ "wallabag" ];
        ensureUsers = [
          {
            name = "wallabag";
            ensurePermissions = {
              "wallabag.*" = "ALL PRIVILEGES";
            };
          }
        ];
      };

      systemd.services = {

      # I wanted to copy and install in the same unit but copying is too expensive
      # because it comes with like one trillion files, so just copy in this unit and
      # install in another one so I can only run install while I test it
      copy-wallabag = {
        description = "Copy wallabag to final directory and setting permissions for installation";

        script = ''
          echo '>>> Copying all wallabag files from the store to ${cfg.directory}'
          cp -r ${cfg.package}/* ${cfg.directory}
          echo '>>> Setting write permissions to /app/config/parameters.yml'
          chmod u+w ${cfg.directory}/app ${cfg.directory}/app/config ${cfg.directory}/app/config/parameters.yml
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
            parameters = ''
              parameters:
      # Uncomment these settings or manually update your parameters.yml
      # to use docker-compose
      #
      # database_driver: %env.database_driver%
      # database_host: %env.database_host%
      # database_port: %env.database_port%
      # database_name: %env.database_name%
      # database_user: %env.database_user%
      # database_password: %env.database_password%

              database_driver: pdo_mysql
              database_host: 127.0.0.1
              database_port: ~
              database_name: ${cfg.database.name}
              database_user: ${cfg.database.user}
              database_password: ~
      # For SQLite, database_path should be "%kernel.project_dir%/data/db/wallabag.sqlite"
              database_path: null
              database_table_prefix: wallabag_
              database_socket: null
      # with PostgreSQL and SQLite, you must set "utf8"
              database_charset: utf8mb4

              domain_name: https://your-wallabag-url-instance.com
              server_name: "Your wallabag instance"

              mailer_transport:  smtp
              mailer_user:       ~
              mailer_password:   ~
              mailer_host:       127.0.0.1
              mailer_port:       false
              mailer_encryption: ~
              mailer_auth_mode:  ~

              locale: en

              # TODO: What happens if this changes?
      # A secret key that's used to generate certain security-related tokens
              secret: $(${pkgs.libressl}/bin/openssl rand -hex 12)

      # two factor stuff
              twofactor_auth: true
              twofactor_sender: no-reply@wallabag.org

      # fosuser stuff
              fosuser_registration: true
              fosuser_confirmation: true

      # how long the access token should live in seconds for the API
              fos_oauth_server_access_token_lifetime: 3600
      # how long the refresh token should life in seconds for the API
              fos_oauth_server_refresh_token_lifetime: 1209600

              from_email: no-reply@wallabag.org

              rss_limit: 50

      # RabbitMQ processing
              rabbitmq_host: localhost
              rabbitmq_port: 5672
              rabbitmq_user: guest
              rabbitmq_password: guest
              rabbitmq_prefetch_count: 10

      # Redis processing
              redis_scheme: tcp
              redis_host: localhost
              redis_port: 6379
              redis_path: null
              redis_password: null

      # sentry logging
              sentry_dsn: ~
            '';
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
          After = [ "create-parameters.service" "mysql.service" ];
          Requires = [ "create-parameters.service" "mysql.service" ];
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
