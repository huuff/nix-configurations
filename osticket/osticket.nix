{ config, pkgs, lib, ... }:
let
  osTicket = pkgs.callPackage ./osticket-derivation.nix {};
  directory = "/var/www/osticket";
in
  {
  # XXX osTicket installation seems to need it. Is there any way to provide it only to the systemd unit?
  # still, I'm not sure it's working at all, journalctl -fu to see hundreds of failed git commands
  environment.systemPackages = [ pkgs.git ];

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
    users.osticket = {
      isSystemUser = true;
      home = directory;
      group = "osticket";
      extraGroups = [ "keys" ]; # needed for nixops, to access /run/keys
      createHome = true; # remove it? I'm creating the directory in the activation script anyway
    };

    groups.osticket = {}; # create the group
  };

  systemd.services.nginx.serviceConfig.ProtectHome = "read-only";
  systemd.services.nginx.serviceConfig.ReadWritePaths = [ directory ];

  services.nginx = {
    enable = true;
    user = "osticket";
    group = "osticket";

    virtualHosts.osticket = {
      enableACME = false;
      root = directory;
      locations."/" = {
        extraConfig = ''
          try_files $uri $uri/ index.php;
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:${config.services.phpfpm.pools.osTicket.socket};
          include ${pkgs.nginx}/conf/fastcgi_params;
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
      };
    };
  };

  services.phpfpm.pools.osTicket = {
    user = "osticket";
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

  # XXX Will this be run on every activation?
  systemd.services.osticket-copy-to-dir = {
    script = ''
        cp -rv * ${directory}
    '';

    wantedBy = [ "default.target" ];
    serviceConfig = {
      User = "osticket";
      Type = "oneshot";
      WorkingDirectory = osTicket;
    };
  };
}
