{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.wallabag;
  mkDatabaseModule = import ../../lib/mkDatabaseModule.nix;
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
          User = cfg.user;
          Type = "oneshot";
          WorkingDirectory = cfg.directory;
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
      user = cfg.user;
      group = cfg.user;

      virtualHosts.wallabag = {
        root = "${cfg.directory}/web";
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
        user = cfg.user;
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
