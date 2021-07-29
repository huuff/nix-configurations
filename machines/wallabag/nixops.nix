{
  network.description = "Wallabag testing deploy";

  wallabag = { config, pkgs, lib, ... }:
  let
    myLib = import ../../lib { inherit lib; };
  in
  {
    imports = [
      (import ./default.nix { inherit myLib; })
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
