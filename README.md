# Nix Machines
Run tests using `nix build .#nixosTests.<testname> --no-sandbox -L`. Disabling sandboxing is going to be necessary for most tests since they use internet access.
