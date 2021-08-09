# TODO
* Maybe Zammad? osTicket seems dated
* A module or library for `PHP` + `nginx`, but I find it difficult since I just copypaste nginx configurations from the internet.
* I'm making some efforts to get these to work for an installation with multiple modules at the same time, but does it? I've never tested.
* In `osTicket` and `wallabag`, is there any way I can test that users can login? Maybe I need to automate the browser?

## Neuron
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling. UPDATE: Redirecting the `doOnRequest` log to somewhere and reading it? UPDATE: Is it still necessary? I've tested `doOnRequest` after all

## osTicket
* Add backup options
* Add email options

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Wallabag
* `copy-wallabag` is really slow on some computers, is it a KVM thing?
* Backup options, there's nothing yet but it's pretty important
* What about auto-importing pocket?
* Add email options

## mkInitModule
* Add an intermediate "lock" for each unit, so these can show at what point of the initialization we are, and thus, restart from an intermediate point instead of from the beginning.

## mkSSLModule
* Option to add own certificate
* Option to generate one from Let's Encrypt
* Check and generate certificates if they are expired

## Mail/SNM
* Give it some love
