{ config, pkgs, ... }:
let
  osTicket = pkgs.callPackage ./osticket-derivation.nix {};
in
{
  # XXX osTicket installation seems to need it. Is there any way to provide it only to the systemd unit?
  # still, I'm not sure it's working at all, journalctl -fu to see hundreds of failed git commands
  environment.systemPackages = [ pkgs.git ];

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = pkgs.writeText "initScript" ''
      CREATE DATABASE osticket;
      CREATE USER 'osticket'@'localhost';
      GRANT ALL PRIVILEGES ON osticket.* TO 'osticket'@'localhost' IDENTIFIED BY 'password';
      '';
  };

  systemd.services.osTicket-first-deploy = {
    script = ''
        mkdir -p /var/www/osticket/
        ${pkgs.php74}/bin/php manage.php deploy --setup /var/www/osticket/
      '';

    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = osTicket;
    };
  };
}
