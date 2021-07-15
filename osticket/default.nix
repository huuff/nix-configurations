{ pkgs ? import <nixpkgs> {} }:

pkgs.callPackage ./osticket-derivation.nix {}
