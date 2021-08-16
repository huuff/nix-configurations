# TODO
* Maybe Zammad? osTicket seems dated
* A module or library for `PHP` + `nginx`, but I find it difficult since I just copypaste nginx configurations from the internet.
* In `osTicket` and `wallabag`, is there any way I can test that users can login? Maybe I need to automate the browser?
* I think I've used `mkEnableOption` wrong every single time. It takes a name, not a description.
* Harden long-standing systemd services (`do-on-request`, `auto-rsync`)
* A hardened `openssh` module like that in [this post](https://christine.website/blog/paranoid-nixos-2021-07-18)
* Make a file with the `test` config and share it between `test.nix` and `vm.nix` to test interactively in the same test environment (Ideally, I'd get `shell_interact()` to work. Or maybe not? I like having my aliases available).

## Neuron
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling. UPDATE: Redirecting the `doOnRequest` log to somewhere and reading it? UPDATE: Is it still necessary? I've tested `doOnRequest` after all. UPDATE: Yeah but these are integration tests and testing the individual components does not guarantee that they all work together

## Multi-machine deploy
* `nginx` has one user set for each machine and they conflict.
* Add a way to setup a global certificate, this will help with deploying multiple machines.

## osTicket
* Add backup options
* Add email options

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme. UPDATE: Maybe just implement the module myself, there's a good chance I'll have to anyway
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Wallabag
* `copy-wallabag` is really slow on some computers, is it a KVM thing?
* Backup options, there's nothing yet but it's pretty important
* Add email options
* I think the DB can be authenticated as a Unix socket, check it.
* `install-dependencies` should definitely fail when it fails or else `setup-users` fails.

## mkInitModule
* Add an intermediate "lock" for each unit, so these can show at what point of the initialization we are, and thus, restart from an intermediate point instead of from the beginning.
* Make it somewhat more terse. My init scripts still look a bit hideous

## mkDatabaseModule
* Add `postgres`
* Allow also UNIX socket users.
* `execDDL` and `execDML` would be better as `runDDL` and `runDML`, also, `execDDL` isn't even really for DDL

## mkSSLModule
* Option to add own certificate
* Option to generate one from Let's Encrypt
* Check and generate certificates if they are expired
* Definitely needs to follow the path convention

## Mail
* Test that I can send and receive mail to and from users (`postfix`). UPDATE: Test mail between two machines running the same configuration.
* Test that I can access the mail from outside (`dovecot`)

## Postfix
Okay I've decided to try again to implement it myself:
* A format for specifying any map
* Get it working with virtual mailboxes since that is what I care about the most.
* Remove the todos from `mail`?
* Remove `sleep`'s from the test, and use some `wait_for` function
