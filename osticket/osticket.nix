{ config, pkgs, lib, ... }:
let
  osTicket = pkgs.callPackage ./osticket-derivation.nix {};
  directory = "/var/www/osticket";
  user = "osticket";
in
  {
  system.activationScripts = {
    # Maybe I should put this into some library since it's pretty useful
    prepareDir = ''
        echo "SETTING EXECUTE PERMISSIONS ON ALL DIRECTORIES UP TO ${directory}"
        mkdir -p ${directory}
        dirsUpToPath=$(namei ${directory} | tail -n +3 | cut -d' ' -f3)

        currentPath=""
        for dir in $dirsUpToPath
        do
          currentPath="$currentPath/$dir"
          chmod og+x "$currentPath"
        done
    '';
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = pkgs.writeText "initScript" ''
      CREATE DATABASE osticket;
      CREATE USER 'osticket'@'localhost';
      GRANT ALL PRIVILEGES ON osticket.* TO 'osticket'@'localhost' IDENTIFIED BY 'password';
    '';
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
      locations."/" = {
      extraConfig = ''
          index index.php;
        '';
      };
      locations."~ \.php$" = {
        extraConfig = ''
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:${config.services.phpfpm.pools.osTicket.socket};
          include ${pkgs.nginx}/conf/fastcgi_params;
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
      };
      locations."~ ^/scp/ajax.php/.*$" = {
        extraConfig = ''
            try_files $uri $uri/ /scp/ajax.php?$query_string;
          '';
      };
    };
  };

  services.phpfpm.pools.osTicket = {
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

  # XXX Will this be run on every activation?
  systemd.services.osticket-copy-to-dir = {
    script = ''
        set -x
        cp -rv ${osTicket}/* ${directory}
        find ${directory} -type d -print0 | xargs -0 chmod 0755
        find ${directory} -type f -print0 | xargs -0 chmod 0644
        mv ${directory}/include/ost-sampleconfig.php ${directory}/include/ost-config.php
        chmod 0666 ${directory}/include/ost-config.php
    '';

    wantedBy = [ "default.target" ];
    serviceConfig = {
      User = user;
      Type = "oneshot";
      ReadWritePaths = [ directory ];
      #WorkingDirectory = osTicket;
    };
  };
}
