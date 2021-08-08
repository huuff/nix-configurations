# TODO
* Maybe Zammad? osTicket seems dated
* A module or library for PHP + nginx, but I find it difficult since I just copypaste nginx configurations from the internet.
* Big module idea: One that simplifies creating and running a list of `systemd` units that run one after the other only on first activation.
* I'm making some efforts to get these to work for an installation with multiple modules at the same time, but does it? I've never tested.
* In `osTicket` and `wallabag`, is there any way I can test that users can login? Maybe I need to automate the browser?
* Remove `isNull`'s. It's deprecated.

## Testing library
* Look into adding my functions as some kind of extension methods for `machine`

## Neuron
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling

## osTicket
* Add backup options
* Add email options
* Currently, I have a hack for `setup-users` to launch only on first boot. Manage to get `ConditionFirstBoot` to work in order to remove it.

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Wallabag
* `copy-wallabag` is really slow on some computers, is it a KVM thing?
* Backup options, there's nothing yet but it's pretty important
* Get `install-wallabag` to run only on first boot
* What about auto-importing pocket?

## ensurePaths
* Allow to add just a path string instead of a full set

## mkInitModule
* Use it in my modules
* Test order
* Allow to add paths
* Allow to add extra dependencies

## mkSSLModule
* Option to add own certificate
* Option to generate one from Let's Encrypt
* Generate certificates for the name of the service.
* I'm forcing SSL, but am I redirecting `http` to `https`?

## Mail/SNM
* Give it some love
