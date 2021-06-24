#!/usr/bin/env bash
set -euo

nix-build '<nixpkgs/nixos>' -A vm --arg configuration ./demo.nix
export QEMU_NET_OPTS="hostfwd=tcp::2221-:22,hostfwd=tcp::8080-:80"
result/bin/run-nixos-vm
