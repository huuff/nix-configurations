{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.osticket;
  myLib = import ../../lib/default.nix { inherit config; };
  mkDatabaseModule = import ../../lib/mkDatabaseModule.nix;

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
        (mkDatabaseModule "osticket")
    ];

    options.services.osticket = with types; {
      enable = mkEnableOption "osTicket ticketing system";

      user = mkOption {
        type = str;
        default = "osticket";
        description = "OS user on which to run osTicket";
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

      admin = {
        username = mkOption {
          type = str;
          description = "Username of the admin account";
        };

        email = mkOption {
          type = str;
          description = "Email of the admin account";
        };

        passwordFile = mkOption {
          type = oneOf [ str path ];
          description = "Path to the file with the hashed password of the admin user";
        };

        firstName = mkOption {
          type = str;
          description = "First name of the admin";
        };

        lastName = mkOption {
          type = str;
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
          description = "E-mail of the site";
        };
      };

      users = mkOption {
          type = listOf userModule;
          default = [];
          description = "List of initial osTicket users";
      };

      ssl = {
        enable = mkEnableOption "Enable SSL in the server";

        certificate = mkOption {
          type = oneOf [ str path ];
          description = "SSL certficiate of the server";
        };

        key = mkOption {
          type = oneOf [ str path ];
          description = "Key of the SSL certificate";
        };
      };
    };

    config = mkIf cfg.enable {
      assertions = [
        {
          assertion = all (user: user.passwordFile != null && pathExists user.passwordFile) cfg.users;
          message = "passwordFile must be set for all users, and point to an existing file!";
        }
        {
          assertion = all (user: user.email != null) cfg.users;
          message = "email must be set for all users!";
        }
        {
          assertion = cfg.admin.passwordFile != null && pathExists cfg.admin.passwordFile;
          message = "admin.passwordFile must be set and point to an existing file!";
        }
      ];


    environment.systemPackages = with pkgs; [
      # I'm using these two just for testing on nixos-shell
      php74 
      vim
    ];

    networking.firewall = {
      allowedTCPPorts = [ 80 ] ++ optional cfg.ssl.enable 443;
    };

    # TODO: Creating the directory wouldn't be necessary if createHome were working
    # is it that it's badly ordered?
    # I can't think of any solution to the problem of setting the executable bit
    system.activationScripts.createDirectory = ''
        echo ">>> Creating directory and setting permissions"
        mkdir -p ${cfg.directory}
        dirsUpToPath=$(namei ${cfg.directory} | tail -n +3 | cut -d' ' -f3)

        currentPath=""
        for dir in $dirsUpToPath
        do
          currentPath="$currentPath/$dir"
          chmod og+x "$currentPath"
        done
    '';

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
      } // optionalAttrs cfg.ssl.enable {
        addSSL = true;
        sslCertificate = cfg.ssl.certificate;
        sslCertificateKey = cfg.ssl.key;
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
        };
        phpEnv."PATH" = lib.makeBinPath [ pkgs.php74 ];
      };
    };

    systemd.services = {
      deploy-osticket = {
        description = "Copy osTicket files and set permissions";

        script = ''
            echo ">>> Copying files to ${cfg.directory}"
            cp -r ${cfg.package}/* ${cfg.directory}

            echo ">>> Setting permissions for serving"
            find ${cfg.directory} -type d -print0 | xargs -0 chmod 0755
            find ${cfg.directory} -type f -print0 | xargs -0 chmod 0644
        '';

        unitConfig = {
          ConditionDirectoryNotEmpty = "!${cfg.directory}";
        };

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      install-osticket = {
        description = "Run osTicket installation script and cleanup";

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
            -F "passwd=passwd" \
            -F "passwd2=passwd" \
            -F "prefix=${cfg.database.prefix}" \
            -F "dbhost=${cfg.database.host}" \
            -F "dbname=${cfg.database.name}" \
            -F "dbuser=${cfg.database.user}" \
            -F "dbpass=${myLib.catPasswordFile cfg.database.passwordFile}"
          echo ">>> Performing post-install cleanup"
          chmod 0644 ${cfg.directory}/include/ost-config.php
          rm -r ${cfg.directory}/setup

          # TODO: This is a temporary hack for running setup-users only on first boot
          # remove it when I get ConditionFirstBoot to work
          touch ${cfg.directory}/setup-users
        '';

        unitConfig = {
          After = [ "nginx.service" "phpfpm-osTicket.service" "mysql.service" "setup-osticket-db.service" "deploy-osticket.service" ];
          Requires = [ "nginx.service" "phpfpm-osTicket.service" "mysql.service" "setup-osticket-db.service" "deploy-osticket.service" ];
          ConditionPathExists = "${cfg.directory}/setup";
        };

        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      setup-users =
      let
        updateAdminPass = ''
          UPDATE ${cfg.database.prefix}staff SET passwd='${myLib.catPasswordFile cfg.admin.passwordFile}' WHERE staff_id=1;
        '';
        insertUser = user: ''
          START TRANSACTION;
          INSERT INTO ${cfg.database.prefix}user (org_id, default_email_id, name, created, updated) VALUES (0, 0, '${user.fullName}', NOW(), NOW());
          SELECT LAST_INSERT_ID() INTO @user_id;
          INSERT INTO ${cfg.database.prefix}user_email (user_id, address) VALUES (@user_id, '${user.email}');
          SELECT LAST_INSERT_ID() INTO @email_id;
          UPDATE ${cfg.database.prefix}user SET default_email_id=@email_id WHERE id=@user_id;
          INSERT INTO ${cfg.database.prefix}user_account (user_id, ${optionalString (user.username != null) "username,"} status, passwd) VALUES (@user_id, ${optionalString (user.username != null) "'${user.username}',"} 1, '${myLib.catPasswordFile user.passwordFile}');
          COMMIT;
          '';
          userToDML = map (user: (myLib.db.execDML cfg (insertUser user))) cfg.users;
      in {
        description = "Create initial osTicket users";

        script = ''
          ${myLib.db.execDML cfg updateAdminPass}

          ${concatStringsSep "\n" userToDML}

          # TODO: Remove it when I get ConditionFirstBoot to work
          rm ${cfg.directory}/setup-users
          '';

        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          After = [ "install-osticket.service" ];
          Requires = [ "install-osticket.service" ];
          ConditionPathExists = "${cfg.directory}/setup-users";
        };


        serviceConfig = {
          User = cfg.user;
          Type = "oneshot";
          RemainAfterExit = "true";
        };
      };

    };
  };
}