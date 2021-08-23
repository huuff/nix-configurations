{ pkgs ? import <nixpkgs> {} }:
{
  delivery = import ./delivery-test.nix { inherit pkgs; };
  virtual = import ./virtual-test.nix { inherit pkgs; };
  restrictions = import ./restrictions-test.nix { inherit pkgs; };
}
