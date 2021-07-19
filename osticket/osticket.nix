{ config, pkgs, lib, ... }:
let
  cfg = config.services.osticket;
in with lib;
  {
    options.services.osticket = {
      enable = mkEnableOption "osTicket ticketing system";

      user = mkOption {
        type = types.str;
        default = "osticket";
        description = "User on which to run osTicket";
      };

      directory = mkOption {
        type = types.str;
        default = "/var/www/osticket";
        description = "Directory where to install and serve osTicket";
      };

      # TODO: This shouldn't need to be provided by the user, only the password
      initialScript = mkOption {
        type = types.path;
        default = null;
        description = "Initial script with which to load the DB";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.callPackage ./derivation.nix {};
        description = "The package that provides osTicket";
      };

      admin = {
        username = mkOption {
          type = types.str;
          default = null;
          description = "Username of the admin account";
        };

        email = mkOption {
          type = types.str;
          default = null;
          description = "Email of the admin account";
        };

        # TODO: this shouldn't be here because Nix doesn't manage secrets
        password = mkOption {
          type = types.str;
          default = null;
          description = "Password of the admin account";
        };

        firstName = mkOption {
          type = types.str;
          default = null;
          description = "First name of the admin";
        };

        lastName = mkOption {
          type = types.str;
          default = null;
          description = "Last name of the admin";
        };
      };

      database = {
        host = mkOption {
          type = types.str;
          default = "localhost";
          description = "Host location of the database";
        };

        name = mkOption {
          type = types.str;
          default = null;
          description = "Name of the database";
        };

        user = mkOption {
          type = types.str;
          default = null;
          description = "Name of the database user";
        };

        password = mkOption {
          type = types.str;
          default = null;
          description = "Password of the database user";
        };

        prefix = mkOption {
          type = types.str;
          default = "ost_";
          description = "Prefix to put on all tables of the database";
        };
      };

      site = {
        name = mkOption {
          type = types.str;
          default = null;
          description = "Name of the site";
        };

        email = mkOption {
          type = types.str;
          default = null;
          description = "Email of the site";
        };
      };

    };

    config = mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
      # I'm using these two just for testing on nixos-shell
      php74 
      vim
    ];

    # TODO: Creating the directory wouldn't be necessary if createHome were working
    # is it that it's badly ordered?
    # I can't think of any solution to the problem of setting the executable bit
    system.activationScripts.createDirectory = ''
        echo "CREATING DIRECTORIES AND SETTING PERMISSIONS..."
        mkdir -p ${cfg.directory}
        dirsUpToPath=$(namei ${cfg.directory} | tail -n +3 | cut -d' ' -f3)

        currentPath=""
        for dir in $dirsUpToPath
        do
          currentPath="$currentPath/$dir"
          chmod og+x "$currentPath"
        done
    '';

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      initialScript = cfg.initialScript;
    };

    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        home = cfg.directory;
        group = cfg.user;
        extraGroups = [ "keys" ]; # needed for nixops, to access /run/keys
        createHome = true; # remove it? I'm creating the directory in the activation script anyway
      };

      groups.${cfg.user} = {}; # create the group
    };

    # is this useful for anything?
    systemd.services.nginx.serviceConfig.ReadWritePaths = [ cfg.directory ];

    services.nginx = {
      enable = true;
      user = cfg.user;
      group = cfg.user;

      virtualHosts.osticket = {
        root = cfg.directory;
        locations."/".extraConfig = ''
            index index.php;
        '';
        locations."~ \.php$".extraConfig = ''
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools.osTicket.socket};
            include ${pkgs.nginx}/conf/fastcgi_params;
            include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
        locations."~ ^/scp/ajax.php/.*$".extraConfig = ''
            try_files $uri $uri/ /scp/ajax.php?$query_string;
        '';
        locations."/scp".extraConfig = ''
            try_files $uri $uri/ /scp/index.php;
        '';
      };
    };

    services.phpfpm = {
      phpOptions = ''
        extension=${pkgs.php74Extensions.apcu}/lib/php/extensions/apcu.so
      ''; # better performance

      pools.osTicket = {
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
          "security.limit_extensions" = "";
        };
        phpEnv."PATH" = lib.makeBinPath [ pkgs.php74 ];
      };
    };

    systemd.services = {
      deploy-osticket = {
        script = ''
            echo ">>> Copying files to ${cfg.directory}"
            cp -r ${cfg.package}/* ${cfg.directory}

            echo ">>> Setting permissions for serving"
            find ${cfg.directory} -type d -print0 | xargs -0 chmod 0755
            find ${cfg.directory} -type f -print0 | xargs -0 chmod 0644
        '';

        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          ConditionDirectoryNotEmpty = "!${cfg.directory}";
          Description = "Copy osTicket files and set permissions";
        };

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      install-osticket = {
        script = ''
          echo ">>> Setting config file"
          mv ${cfg.directory}/include/ost-sampleconfig.php ${cfg.directory}/include/ost-config.php
          chmod 0666 ${cfg.directory}/include/ost-config.php

          echo ">>> Calling install script"
          ${pkgs.curl}/bin/curl "localhost/setup/install.php" \
            -F "s=install" \
            -F "name=${cfg.site.name}" \
            -F "email=${cfg.site.email}" \
            -F "fname=${cfg.admin.firstName}" \
            -F "lname=${cfg.admin.lastName}" \
            -F "admin_email=${cfg.admin.email}" \
            -F "username=${cfg.admin.username}" \
            -F "passwd=${cfg.admin.password}" \
            -F "passwd2=${cfg.admin.password}" \
            -F "prefix=${cfg.database.prefix}" \
            -F "dbhost=${cfg.database.host}" \
            -F "dbname=${cfg.database.name}" \
            -F "dbuser=${cfg.database.user}" \
            -F "dbpass=${cfg.database.password}"
          echo ">>> Performing post-install cleanup"
          chmod 0644 ${cfg.directory}/include/ost-config.php
          rm -r ${cfg.directory}/setup
        '';

        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          After = [ "nginx.service" "phpfpm-osTicket.service" "mysql.service" "deploy-osticket.service" ]; # any nix way to get the service names? especially phpfpm since it's more likely to change
          ConditionPathExists = "${cfg.directory}/setup";
          Description = "Run osTicket installation script and cleanup";
        };

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
  };
}
