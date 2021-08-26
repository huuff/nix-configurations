{ pkgs, config, lib, ... }:
with lib;
{
  imports = [
    ../../machines/osticket
    ../../machines/wallabag
    ../../machines/neuron
  ];

  services.mysql.package = mkForce pkgs.mariadb;

  virtualisation = {
    memorySize = "2048M";
    diskSize = 5 * 1024;
  };

  machines = {
    osticket = {
      enable = true;

      installation.ports.http = 8080;

      database = {
        authenticationMethod = "password";
        passwordFile = pkgs.writeText "dbpass" "dbpass";
      };

      site = {
        email = "test@example.org";
      };

      admin = {
        username = "root";
        firstName = "Name";
        lastName = "LastName";
        email = "test@test.com";
        passwordFile = pkgs.writeText "pass" "pass";
      };

      installation.group = "nginx";
    };

    wallabag = {
      enable = true;

      installation.ports.http = 8081;

      installation.group = "nginx";
    };

    # TODO: Upstream nixos-shell has an older version of nixpkgs without getFlake?
    #neuron = {
      #enable = true;
      #repository = "https://github.com/srid/alien-psychology.git";

      #installation.group = "nginx";
    #};
  };

  services.nginx.user = mkForce "nginx";


  virtualisation.qemu.networkingOptions = [
    "-net nic,netdev=user.0,model=virtio"
    "-netdev user,id=user.0,hostfwd=tcp::8080-:8080,hostfwd=tcp::8081-:8081"
  ];
}
