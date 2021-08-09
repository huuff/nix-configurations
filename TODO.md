# TODO
* Maybe Zammad? osTicket seems dated
* A module or library for `PHP` + `nginx`, but I find it difficult since I just copypaste nginx configurations from the internet.
* I'm making some efforts to get these to work for an installation with multiple modules at the same time, but does it? I've never tested.
* In `osTicket` and `wallabag`, is there any way I can test that users can login? Maybe I need to automate the browser?
* Remove `isNull`'s. It's deprecated.
* `mkDefaults` in `nginx` users and groups

## Testing library
* Look into adding my functions as some kind of extension methods for `machine`
* Function to run command and print output for debugging

## Neuron
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling. UPDATE: Redirecting the `doOnRequest` log to somewhere and reading it?
* Look into importing the `neuron` package directly in the module

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

## ensurePaths
* Allow to add just a path string instead of a full set

## mkInitModule
* Add an intermediate "lock" for each unit, so these can show at what point of the initialization we are, and thus, restart from an intermediate point instead of from the beginning.

## mkSSLModule
* Option to add own certificate
* Option to generate one from Let's Encrypt
* Generate certificates for the name of the service.
* Check and generate certificates if they are expired
* I'm forcing SSL, but am I redirecting `http` to `https`?

## do-on-request
* I'm sure there are some security issues I've not worked out
* Currently it also runs the script on initialization. Should it?

## autoRsync
* Test it
* Refactor it

## Mail/SNM
* Give it some love
