{ config, pkgs, lib, initialScript, ... }:
let
  osTicket = pkgs.callPackage ./osticket-derivation.nix {};
  directory = "/var/www/osticket";
  user = "osticket";
in
  {

    environment.systemPackages = with pkgs; [
      # I'm using these two just for testing on nixos-shell
      php74 
      vim
    ];

    system.activationScripts.prepare = ''
        echo "CREATING DIRECTORIES AND SETTING PERMISSIONS..."
        mkdir -p ${directory}
        dirsUpToPath=$(namei ${directory} | tail -n +3 | cut -d' ' -f3)

        currentPath=""
        for dir in $dirsUpToPath
        do
          currentPath="$currentPath/$dir"
          chmod og+x "$currentPath"
        done

        echo "COPYING TO DESTINATION..."
        if [ ! "$(ls -A ${directory})" ]; then
          echo ">>> ${directory} is empty, copying osTicket files there"
          cp -r ${osTicket}/* ${directory}
          find ${directory} -type d -print0 | xargs -0 chmod 0755
          find ${directory} -type f -print0 | xargs -0 chmod 0644
          mv ${directory}/include/ost-sampleconfig.php ${directory}/include/ost-config.php
          chmod 0666 ${directory}/include/ost-config.php
        else
          echo ">>> ${directory} not empty, considering already deployed"
        fi
    '';

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      inherit initialScript;
    };

    users = {
      users.${user} = {
        isSystemUser = true;
        home = directory;
        group = user;
        extraGroups = [ "keys" ]; # needed for nixops, to access /run/keys
        createHome = true; # remove it? I'm creating the directory in the activation script anyway
      };

      groups.${user} = {}; # create the group
    };

    systemd.services.nginx.serviceConfig.ReadWritePaths = [ directory ];

    services.nginx = {
      enable = true;
      user = user;
      group = user;

      virtualHosts.osticket = {
        root = directory;
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
        user = user;
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

    systemd.services.install-osticket = {
      script = ''
        set -x
        ${pkgs.curl}/bin/curl "localhost/setup/install.php" \
          -F "s=install" \
          -F "name=Site Name" \
          -F "email=sitemail@example.org" \
          -F "fname=AdminFirstname" \
          -F "lname=AdnminLastname" \
          -F "admin_email=adminemail@example.org" \
          -F "username=adminuser" \
          -F "passwd=adminpass" \
          -F "passwd2=adminpass" \
          -F "prefix=ost_" \
          -F "dbhost=localhost" \
          -F "dbname=osticket" \
          -F "dbuser=osticket" \
          -F "dbpass=password"
      '';

      wantedBy = [ "multi-user.target" ];

      unitConfig = {
        After = [ "nginx.service" "phpfpm-osTicket.service" "mysql.service" ]; # any nix way to get the service names? especially phpfpm since it's more likely to change
      };

      serviceConfig = {
        User = user;
        Type = "oneshot";
      };
    };
  }
