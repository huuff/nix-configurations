{ config, pkgs, lib, ... }:
let
  cfg = config.services.osticket;
in with lib;
  {
    options.services.osticket = with types; {
      enable = mkEnableOption "osTicket ticketing system";

      user = mkOption {
        type = str;
        default = "osticket";
        description = "User on which to run osTicket";
      };

      directory = mkOption {
        type = str;
        default = "/var/www/osticket";
        description = "Directory where to install and serve osTicket";
      };

      package = mkOption {
        type = package;
        default = pkgs.callPackage ./derivation.nix {};
        description = "The package that provides osTicket";
      };

      userFile = mkOption {
        type = oneOf [ str path ];
        default = null;
        description = "Path to a JSON file containing the users to create on startup, at the very least, it should contain the admin user. The example is that of the file and not of the option";
        example = literalExample ''
        {
          "root": {
            "password":"passwd"
           },
          "user1": {
            "password":"passwd1"
           }
        }
          '';
      };

      admin = {
        username = mkOption {
          type = str;
          default = null;
          description = "Username of the admin account. This will be used to look for its password in the userFile";
        };

        email = mkOption {
          type = str;
          default = null;
          description = "Email of the admin account";
        };

        firstName = mkOption {
          type = str;
          default = null;
          description = "First name of the admin";
        };

        lastName = mkOption {
          type = str;
          default = null;
          description = "Last name of the admin";
        };
      };

      database = {
        host = mkOption {
          type = str;
          default = "localhost";
          description = "Host location of the database";
        };

        name = mkOption {
          type = str;
          default = null;
          description = "Name of the database";
        };

        user = mkOption {
          type = str;
          default = null;
          description = "Name of the database user";
        };

        passwordFile = mkOption {
          type = oneOf [ str path ];
          default = null;
          description = "Password of the database user";
        };

        prefix = mkOption {
          type = str;
          default = "ost_";
          description = "Prefix to put on all tables of the database";
        };
      };

      site = {
        name = mkOption {
          type = str;
          default = null;
          description = "Name of the site";
        };

        email = mkOption {
          type = str;
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

    networking.firewall = {
      allowedTCPPorts = [ 80 ];
    };

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
        extraConfig = ''
        set $path_info "";

        location ~ /include {
            deny all;
            return 403;
        }

        if ($request_uri ~ "^/api(/[^\?]+)") {
            set $path_info $1;
        }

        location ~ ^/api/(?:tickets|tasks).*$ {
            try_files $uri $uri/ /api/http.php?$query_string;
        }

        if ($request_uri ~ "^/scp/.*\.php(/[^\?]+)") {
            set $path_info $1;
        }

        if ($request_uri ~ "^/.*\.php(/[^\?]+)") {
            set $path_info $1;
        }

        location ~ ^/scp/ajax.php/.*$ {
            try_files $uri $uri/ /scp/ajax.php?$query_string;
        }

        location ~ ^/ajax.php/.*$ {
            try_files $uri $uri/ /ajax.php?$query_string;
        }

        location / {
            index index.php;
        }

        location ~ \.php$ {
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include ${pkgs.nginx}/conf/fastcgi_params;
            include ${pkgs.nginx}/conf/fastcgi.conf;
            fastcgi_param PATH_INFO $path_info;
            fastcgi_pass unix:${config.services.phpfpm.pools.osTicket.socket};
        }
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
          "security.limit_extensions" = ""; # TODO: what is this? try removing it
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

      setup-database =
      let
        initialScript = ''
          CREATE DATABASE ${cfg.database.name};
          CREATE USER '${cfg.database.user}'@${cfg.database.host} IDENTIFIED BY '$(cat ${toString cfg.database.passwordFile})';
          GRANT ALL PRIVILEGES ON ${cfg.database.name}.* TO '${cfg.database.user}'@${cfg.database.host};
          '';
      in 
        {
        script = ''
          ${config.services.mysql.package}/bin/mysql -u root -N <<EOF
          ${initialScript}
          EOF
        '';

        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          ConditionPathExists = "${cfg.directory}/setup"; # a.k.a. not yet installed
          After = [ "mysql.service" "deploy-osticket.service" ];
          Description = "Create database and user for osTicket";
        };

        serviceConfig = {
          User = "root"; #TODO: is there any other way?
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      install-osticket = {
        script = 
        let
          jqGetProp = prop: "$(cat ${toString cfg.userFile} | ${pkgs.jq}/bin/jq -r .${cfg.admin.username}.${prop})";
        in
        ''
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
            -F "passwd=${jqGetProp "password"}" \
            -F "passwd2=${jqGetProp "password"}" \
            -F "prefix=${cfg.database.prefix}" \
            -F "dbhost=${cfg.database.host}" \
            -F "dbname=${cfg.database.name}" \
            -F "dbuser=${cfg.database.user}" \
            -F "dbpass=$(cat ${toString cfg.database.passwordFile})"
          echo ">>> Performing post-install cleanup"
          chmod 0644 ${cfg.directory}/include/ost-config.php
          rm -r ${cfg.directory}/setup
        '';

        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          After = [ "nginx.service" "phpfpm-osTicket.service" "mysql.service" "setup-database.service" "deploy-osticket.service" ];
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
