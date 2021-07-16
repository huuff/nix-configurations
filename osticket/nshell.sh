#!/usr/bin/env bash
QEMU_NET_OPTS="hostfwd=tcp::8989-:80" nixos-shell osticket.nix
