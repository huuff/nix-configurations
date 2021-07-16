{ config, pkgs, ... }:
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
        set -x
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

  services.nginx = {
    enable = true;

    virtualHosts.osticket = {
      enableACME = false;
      root = directory;
      locations."/" = {
        
      };
    };
  };

  # XXX Will this be run on every activation?
  systemd.services.osTicket-first-deploy = {
    script = ''
        set -x
        ls ${directory}
        ${pkgs.php74}/bin/php manage.php deploy --setup ${directory}
      '';

    wantedBy = [ "default.target" ];
    serviceConfig = {
      User = "osticket";
      Type = "oneshot";
      WorkingDirectory = osTicket;
    };
  };
}
