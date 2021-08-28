# TASKS
* A module or library for `PHP` + `nginx`, but I find it difficult since I just copypaste nginx configurations from the internet.
* In `osTicket` and `wallabag`, is there any way I can test that users can login? Maybe I need to automate the browser?
* Harden long-standing systemd services (`do-on-request`, `auto-rsync`)
* A hardened `openssh` module like that in [this post](https://christine.website/blog/paranoid-nixos-2021-07-18)
* Make a file with the `test` config and share it between `test.nix` and `vm.nix` to test interactively in the same test environment (Ideally, I'd get `shell_interact()` to work. Or maybe not? I like having my aliases available) UPDATE: I DEFINITELY need to use `shell_interact()`, anything else is just torture. Maybe I'll have to ask the discourse. UPDATE: Idea: Use some `default.nix` for tests I want to interact with, import `nixpkgs` from the channel and pass it to the test file as a parameter. UPDATE: It doesn't work either. Seems like nobody cares much about `shell_interact()`?
* Maybe it's time to start passing my library from the flake, look at that import for `testing-lib` in the `virtual-test` for postfix.
* Does `mkEnableOption` protect against using other options? I don't think so but test it. Especially for `mkSSLModule`, I want to know if I can set `httpsOnly` without `enable` (And if I can, prevent it with an assertion)

# nixosShellBase
* Configuration to forward ports.

## Testing library
* Some wrapper around `wait_until_tty_matches` with a timeout, setting current tty and printing.
* `contains` could be `match` and accept a regex
* `current_tty` could be an instance variable in `Machine`. Currently, two different machines on two different ttys could cause interference with this.
* Why use `fileFromStore` in my tests? I could get the same and more concisely with just `pkgs.writeText`

## Neuron
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling. UPDATE: Redirecting the `doOnRequest` log to somewhere and reading it? UPDATE: Is it still necessary? I've tested `doOnRequest` after all. UPDATE: Yeah but these are integration tests and testing the individual components does not guarantee that they all work together

## multiDeploy
* Add a way to setup a global certificate, this will help with deploying multiple machines.
* Check that all `mysql` packages are the same.
* Check that no two machines use the same ports.

## osTicket
* Add email options

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme. UPDATE: Maybe just implement the module myself, there's a good chance I'll have to anyway
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

# My library
* Some function to create a `passwordFile` option.

## Wallabag
* `copy-wallabag` is really slow on some computers, is it a KVM thing?
* Add email options

## mkInitModule
* Make it somewhat more terse. My init scripts still look a bit hideous
* Maybe units shouldn't `remainOnExit` since this makes re-initialization harder. Those units that were successful wont be reinitialized until restart (not reactivation). Making removing inits useless.

## mkDatabaseModule
* Add `postgres`

## mkSSLModule
* Option to generate one from Let's Encrypt
* Check and generate certificates if they are expired
* Option to set a global certificate

## mkBackupModule
* Test the timer
* Some way to conditionally load `mkInitModule`? (Not loading it if already loaded)
* Something about exporting the key

## Mail
* Sieve

## Dovecot
* Add it and use it to authenticate `postfix`

## Postfix
* There's a commented out test in `restrictions-test`. Find out what's wrong with it.
* In `attrToMain` (or something like that) get a long list of values to write as a list with indented subsequent entries instead of everything in one line.
* Test that the server is not an open relay
* Test rfc conformance (permits `abuse`, `postmaster` and `<>`)
* `mysql` maps
* TLS
* `clamav`
* Some anti-spam software
