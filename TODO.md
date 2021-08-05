# TODO
* Maybe Zammad? osTicket seems dated
* A module or library for PHP + nginx, but I find it difficult since I just copypaste nginx configurations from the internet.

## Neuron
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling

## osTicket
* Add backup options
* Add email options
* Currently, I have a hack for `setup-users` to launch only on first boot. Manage to get `ConditionFirstBoot` to work in order to remove it.
* Add more tests. I'm genuinely scared I'll break it.

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Wallabag
* `copy-wallabag` is really slow on some computers, is it a KVM thing?
* Backup options, there's nothing yet but it's pretty important
* Get `install-wallabag` to run only on first boot
* Test it, even though it's a pain to even run it in some computers
* What about auto-importing pocket?
* I broke it at some point. Pushing anyway

## mkSSLModule
* Option to add own certificate
* Option to generate one from Let's Encrypt

## mkInstallationModule
* Test it

## mkDatabaseModule
* Test it
* `mkIf enable`?
* Change name to kebab.case

## Mail/SNM
* Give it some love
