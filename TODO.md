# TASKS
* A module or library for `PHP` + `nginx`, but I find it difficult since I just copypaste nginx configurations from the internet.
* In `osTicket` and `wallabag`, is there any way I can test that users can login? Maybe I need to automate the browser?
* Make a file with the `test` config and share it between `test.nix` and `vm.nix` to test interactively in the same test environment (Ideally, I'd get `shell_interact()` to work. Or maybe not? I like having my aliases available) UPDATE: I DEFINITELY need to use `shell_interact()`, anything else is just torture. Maybe I'll have to ask the discourse. UPDATE: Idea: Use some `default.nix` for tests I want to interact with, import `nixpkgs` from the channel and pass it to the test file as a parameter. UPDATE: It doesn't work either. Seems like nobody cares much about `shell_interact()`?
* Move all modules to the `modules` folder

## Testing library
* Some wrapper around `wait_until_tty_matches` with a timeout, setting current tty and printing.

## multiDeploy
* Add a way to setup a global certificate, this will help with deploying multiple machines.
* Check that all `mysql` packages are the same. UPDATE: I think it's impossible
* Check that no two machines use the same ports.

## osTicket
* IDEMPOTENCE: Change DB parameters after installation
* IDEMPOTENCE: Change any user information after installation.
* Add email options

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme. UPDATE: Maybe just implement the module myself, there's a good chance I'll have to anyway
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Wallabag
* IDEMPOTENCE: Should be possible to change any user data declaratively after installation
* Add email options

## mkInitModule
* Make it somewhat more terse. My init scripts still look a bit hideous
* Some way for some units to be superseded by backup restoring. UPDATE: Or prevent using them with assertions?

## mkDatabaseModule
* Add `postgres`

## mkSSLModule
* Option to generate one from Let's Encrypt
* Check and generate certificates if they are expired
* Option to set a global certificate

## mkBackupModule
* Something about exporting the key
* Add compression options
* Backing up installation directory instead of random directories (or in addition to?)

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
