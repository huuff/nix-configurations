{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wallabag;
  mkDatabaseModule = import ../../lib/mkDatabaseModule.nix;
  mkSSLModule = import ../../lib/mk-ssl-module.nix;
  mkInstallationModule = import ../../lib/mk-installation-module.nix;
  myLib = import ../../lib/default.nix { inherit config pkgs; };

  phpWithTidy = pkgs.php74.withExtensions ( { enabled, all }: enabled ++ [ all.tidy ] );
  composerWithTidy = (pkgs.php74Packages.composer.override { php = phpWithTidy; });
  userModule = with types; submodule {
    options = {
      username = mkOption {
        type = str;
        description = "Username of the user";
      };

      passwordFile = mkOption {
        type = oneOf [ str path ];
        description = "Path to the file containing the salt in the first line and the encrypted password in the second";
      };

      email = mkOption {
        type = str;
        description = "E-mail address of the user";
      };
    };
  };
in
  {

    imports = [
      (mkDatabaseModule "wallabag")
      (mkSSLModule "wallabag")
      (mkInstallationModule "wallabag")
    ];

    options.services.wallabag = with types; {
      enable = mkEnableOption "Whether to enable the wallabag service";

      package = mkOption {
        type = package;
        default = pkgs.wallabag;
        description = "The wallabag package to use";
      };

      users = mkOption {
        type = listOf userModule;
        default = [];
        description = "List of initial wallabag users";
      };

    };

    config = mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        phpWithTidy
        composerWithTidy
      ];

      systemd.services = {

      # I wanted to copy and install in the same unit but copying is too expensive
      # because it comes with like one trillion files, so just copy in this unit and
      # install in another one so I can only run install while I test it
      copy-wallabag = {
        description = "Copy wallabag to final directory and setting permissions for installation";

        script = ''
          echo '>>> Copying all wallabag files from the store to ${cfg.installation.path}'
          cp -r ${cfg.package}/* ${cfg.installation.path}
          echo '>>> Setting write permissions to ${cfg.installation.path}'
          chmod -R u+w ${cfg.installation.path}
        '';

        serviceConfig = {
          User = cfg.installation.user;
          Type = "oneshot";
          WorkingDirectory = cfg.installation.path;
          RemainAfterExit = true;
        };

        unitConfig = {
          ConditionDirectoryNotEmpty = "!${cfg.installation.path}";
          After = [ "ensure-paths.service" ];
          Requires = [ "ensure-paths.service" ];
        };
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
  database_password: ${myLib.passwd.cat cfg.database.passwordFile}
    # For SQLite, database_path should be "%kernel.project_dir%/data/db/wallabag.sqlite"
  database_path: null
  database_table_prefix: ${cfg.database.prefix}
  database_socket: null
    # with PostgreSQL and SQLite, you must set "utf8"
  database_charset: utf8mb4

    # TODO: Make this configurable
  domain_name: ${if cfg.ssl.enable then "https" else "http"}://$(curl https://ipinfo.io/ip) # TODO: Fragile? And untestable
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
          rm ${cfg.installation.path}/app/config/parameters.yml
          echo "${parameters}" >> ${cfg.installation.path}/app/config/parameters.yml
        '';

        serviceConfig = {
          User = cfg.installation.user;
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
          make clean
          make install
        ''; 

        wantedBy = [ "multi-user.target" ];

        path = with pkgs; [ 
          gnumake
          bash
          composerWithTidy
          phpWithTidy
        ];

        serviceConfig = {
          User = cfg.installation.user;
          Type = "oneshot";
          WorkingDirectory = cfg.installation.path;
          RemainAfterExit = true;
        };

        unitConfig = {
          After = [ "create-parameters.service" "setup-wallabag-db.service" ];
          Requires = [ "create-parameters.service" "setup-wallabag-db.service" ];
        };
      };

      # TODO: Is this the correct unit for installing dependencies?
      setup-users = {
        description = "Create default users";

        script = 
        let
        insertUser = user: "php bin/console fos:user:create ${user.username} ${user.email} ${myLib.passwd.cat user.passwordFile}";
        in ''
          echo '>>> Installing dependencies'
          COMPOSER_MEMORY_LIMIT=-1 composer install | true
          echo '>>> Disabling default "wallabag" user'
          php bin/console fos:user:deactivate wallabag
          echo '>>> Creating all users'
          ${concatStringsSep "\n" (map (user: insertUser user) cfg.users)}
          '';

        wantedBy = [ "multi-user.target" ];

        path = [ composerWithTidy phpWithTidy ];

        serviceConfig = {
          User = cfg.installation.user;
          Type = "oneshot";
          WorkingDirectory = cfg.installation.path;
          RemainAfterExit = true;
        };

        unitConfig = {
          After = [ "install-wallabag.service" ];
          Requires = [ "install-wallabag.service" ];
        };
      };
    };

    services.nginx = {
      enable = true;
      user = cfg.installation.user;
      group = cfg.installation.user;

      virtualHosts.wallabag = {
        root = "${cfg.installation.path}/web";
        extraConfig = ''
    location / {
        # try to serve file directly, fallback to app.php
        try_files $uri /app.php$is_args$args;
    }
    location ~ ^/app\.php(/|$) {
        # if, for some reason, you are still using PHP 5,
        # then replace /run/php/php7.0 by /var/run/php5
        fastcgi_pass unix:${config.services.phpfpm.pools.wallabag.socket};
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include ${pkgs.nginx}/conf/fastcgi_params;
        include ${pkgs.nginx}/conf/fastcgi.conf;
        # When you are using symlinks to link the document root to the
        # current version of your application, you should pass the real
        # application path instead of the path to the symlink to PHP
        # FPM.
        # Otherwise, PHP's OPcache may not properly detect changes to
        # your PHP files (see https://github.com/zendtech/ZendOptimizerPlus/issues/126
        # for more information).
        fastcgi_param  SCRIPT_FILENAME  $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        # Prevents URIs that include the front controller. This will 404:
        # http://domain.tld/app.php/some-path
        # Remove the internal directive to allow URIs like this
        internal;
    }

    # return 404 for all other php files not matching the front controller
    # this prevents access to other php files you don't want to be accessible.
    location ~ \.php$ {
        return 404;
    }

    error_log /var/log/nginx/wallabag_error.log;
    access_log /var/log/nginx/wallabag_access.log;
        '';
      };
    };


    services.phpfpm = {
      pools.wallabag = {
        user = cfg.installation.user;
        phpPackage = pkgs.php74;
        settings = {
          "listen.owner" = config.services.nginx.user;
          "pm" = "dynamic";
          "pm.max_children" = 32;
          "pm.max_requests" = 500;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 5;
          "php_admin_value[error_log]" = "stderr";
          "php_admin_flag[log_errors]" = true;
          "catch_workers_output" = true;
        };
        phpEnv."PATH" = lib.makeBinPath [ pkgs.php74 ];
      };
    };
  };
}
