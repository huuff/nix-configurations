# Nix Machines

## Running tests
Since some of them require internet access, it's necessary to add `--no-sandbox` (they are run in a VM anyway)

* For individual tests use `nix build .#checks.x86_64-linux.<testname> --no-sandbox -L`. (`-L` to show full log)
* To run all tests run `nix flake check --no-sandbox`
