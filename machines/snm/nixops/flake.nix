{
  description = "Mail server with Roundcube";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.05";
    nixops.url = "github:NixOS/nixops";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixops, utils, ... }:
  {
    nixopsConfigurations.default =
      {
        inherit nixpkgs;

        network.description = "SNM";

        mailserver = import ./mail.nix;
      };
    };

  }
