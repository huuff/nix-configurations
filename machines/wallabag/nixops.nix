{
  network.description = "Wallabag testing deploy";

  wallabag = { config, pkgs, lib, ... }:
  {
    imports = [
      ./default.nix
    ];

    services.wallabag = {
      enable = true;
    };

    deployment = {
      targetEnv = "virtualbox";
      virtualbox.headless = true;
    };
  };
}
