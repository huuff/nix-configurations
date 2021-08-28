{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.osticket;
  myLib = import ../../lib/default.nix { inherit config pkgs lib; };

  userModule = with types; submodule {
    options = {
      username = mkOption {
        type = nullOr str;
        default = null;
        description = "Username of the user";
      };

      fullName = mkOption {
        type = str;
        description = "Full name of the user";
      };

      passwordFile = mkOption {
        type = oneOf [ str path ];
        description = "File containing the bcrypt hash of the user's password";
      };

      email = mkOption {
        type = str;
        description = "E-mail address of the user";
      };
    };
  };
in {
  imports = [
    (import ../../lib/mk-database-module.nix "osticket")
    (import ../../modules/ssl "osticket")
    (import ../../modules/backup "osticket")
    (import ../../lib/mk-installation-module.nix "osticket")
    (import ../../lib/mk-init-module.nix "osticket")
    ];

    options.machines.osticket = with types; {
      enable = mkEnableOption "osTicket";

      package = mkOption {
        type = package;
        default = pkgs.callPackage ./derivation.nix {};
        description = "The package that provides osTicket";
      };

      admin = {
        username = mkOption {
          type = str;
          default = "root";
          description = "Username of the admin account";
        };

        email = mkOption {
          type = str;
          default = "admin@example.org";
          description = "Email of the admin account";
        };

        passwordFile = mkOption {
          type = oneOf [ str path ];
          description = "Path to the file with the hashed password of the admin user";
        };

        firstName = mkOption {
          type = str;
          default = "Admin";
          description = "First name of the admin";
        };

        lastName = mkOption {
          type = str;
          default = "Admin";
          description = "Last name of the admin";
        };
      };

      site = {
        name = mkOption {
          type = str;
          default = "osTicket";
          description = "Name of the site";
        };

        email = mkOption {
          type = str;
          default = "osticket@example.org";
          description = "E-mail of the site";
        };
      };

      users = mkOption {
        type = listOf userModule;
        default = [];
        description = "List of initial osTicket users";
      };
    };

    config = mkIf cfg.enable {
      warnings = 
        if (cfg.admin.email == "admin@example.org" || cfg.site.email == "osticket.example.org")
        then [ ''osTicket: You haven't set either the admin's or the site's email. These have defaults to ease testing but it's recommended to set them, otherwise you might be unable to use some features.'' ]
        else [];

      assertions = [
        {
          assertion = cfg.database.authenticationMethod == "password";
          message = "osTicket needs an authenticationMethod of 'password'";
        }
      ];

    systemd.services.nginx.serviceConfig.ReadWritePaths = [ cfg.installation.path ];

    machines.osticket = {
      installation.ports = myLib.mkDefaultHttpPorts cfg;

      initialization.units = [
        {
          name = "deploy-osticket";
          description = "Copy osTicket files and set permissions";
          script = ''
            echo ">>> Copying files to ${cfg.installation.path}"
            cp -r ${cfg.package}/* ${cfg.installation.path}

            echo ">>> Setting permissions for serving"
            find ${cfg.installation.path} -type d -print0 | xargs -0 chmod 0755
            find ${cfg.installation.path} -type f -print0 | xargs -0 chmod 0644
          '';
        }
        {
          name = "install-osticket";
          description = "Run osTicket installation script and cleanup";
          script = let
            protocol = if cfg.ssl.httpsOnly then "https" else "http";
            port = toString (if cfg.ssl.httpsOnly then cfg.installation.ports.https else cfg.installation.ports.http);
          in
          ''
          echo ">>> Setting config file"
          mv ${cfg.installation.path}/include/ost-sampleconfig.php ${cfg.installation.path}/include/ost-config.php
          chmod 0666 ${cfg.installation.path}/include/ost-config.php

            echo ">>> Calling install script"
            ${pkgs.curl}/bin/curl ${optionalString cfg.ssl.httpsOnly "-k"} "${protocol}://localhost:${port}/setup/install.php" \
            -F "s=install" \
            -F "name=${cfg.site.name}" \
            -F "email=${cfg.site.email}" \
            -F "fname=${cfg.admin.firstName}" \
            -F "lname=${cfg.admin.lastName}" \
            -F "admin_email=${cfg.admin.email}" \
            -F "username=${cfg.admin.username}" \
            -F "passwd=passwd" \
            -F "passwd2=passwd" \
            -F "prefix=${cfg.database.prefix}" \
            -F "dbhost=${cfg.database.host}" \
            -F "dbname=${cfg.database.name}" \
            -F "dbuser=${cfg.database.user}" \
            -F "dbpass=${myLib.passwd.cat cfg.database.passwordFile}"
            echo ">>> Performing post-install cleanup"
            chmod 0644 ${cfg.installation.path}/include/ost-config.php
            rm -r ${cfg.installation.path}/setup
          '';
          extraDeps = [ "nginx.service" "phpfpm-osTicket.service" "mysql.service" "setup-osticket-db.service" "deploy-osticket.service" ];
        }
        {
          name = "setup-osticket-users";
          description = "Create initial osTicket users";

          script = let
            updateAdminPass = ''
              UPDATE ${cfg.database.prefix}staff SET passwd='${myLib.passwd.catAndBcrypt cfg.admin.passwordFile}' WHERE staff_id=1;
            '';
            insertUser = user: ''
              START TRANSACTION;
              INSERT INTO ${cfg.database.prefix}user (org_id, default_email_id, name, created, updated) VALUES (0, 0, '${user.fullName}', NOW(), NOW());
              SELECT LAST_INSERT_ID() INTO @user_id;
              INSERT INTO ${cfg.database.prefix}user_email (user_id, address) VALUES (@user_id, '${user.email}');
              SELECT LAST_INSERT_ID() INTO @email_id;
              UPDATE ${cfg.database.prefix}user SET default_email_id=@email_id WHERE id=@user_id;
              INSERT INTO ${cfg.database.prefix}user_account (user_id, ${optionalString (user.username != null) "username,"} status, passwd) VALUES (@user_id, ${optionalString (user.username != null) "'${user.username}',"} 1, '${myLib.passwd.catAndBcrypt user.passwordFile}');
              COMMIT;
            '';
            userToDML = map (user: (myLib.db.runSql cfg.database (insertUser user))) cfg.users;
          in ''
            ${myLib.db.runSql cfg.database updateAdminPass}
            ${concatStringsSep "\n" userToDML}
          '';
        }
      ];
    };

    services.nginx = {
      enable = true;
      user = mkDefault cfg.installation.user;
      group = mkDefault cfg.installation.group;

      virtualHosts.osticket = {
        root = cfg.installation.path;

        listen = myLib.mkListen cfg;

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

          location /scp {
            index /scp/admin.php;
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
