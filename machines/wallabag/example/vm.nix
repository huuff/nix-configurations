{ config, pkgs, lib, ... }:
let
  myLib = import ../../../lib { inherit config pkgs lib; };
  phpWithTidy = pkgs.php74.withExtensions ( { enabled, all }: enabled ++ [ all.tidy ] );
  composerWithTidy = (pkgs.php74Packages.composer.override { php = phpWithTidy; });
in with myLib; {
  imports = [
    ../default.nix
    ../../../lib/nixos-shell-base.nix
  ];

  forwardedPorts = {
    "8989" = "80";
    "8988" = "443";
  };

  virtualisation = {
    memorySize = "2048M";
    diskSize = 5 * 1024;
  };

  environment.systemPackages = with pkgs; [
    phpWithTidy
    composerWithTidy
    gnumake
    doas
  ];
  
  services.redis.logfile = "stdout";
  services.redis.logLevel = "debug";

  machines.wallabag = {
    enable = true;
    ssl.enable = true;
    ssl.sslOnly = true;
    parameters.domain_name = "https://localhost:8988";

    importTool = "rabbitmq";

    users = [
      {
        username = "user1";
        passwordFile = pkgs.writeText "user1pass" "user1pass";
        email = "user1@example.com";
        superAdmin = true;
      }
    ];
  };
}
