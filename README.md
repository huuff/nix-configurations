# Nix Machines
Run tests using `nix build .#checks.x86_64-linux.<testname> --no-sandbox -L`. Disabling sandboxing is going to be necessary for most tests since they use internet access.
