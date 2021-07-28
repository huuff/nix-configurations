# TODO
* Maybe Zammad? osTicket seems dated
* For all systemd services: Put description in the outermost block instead of `unitConfig`
* What about a library for setting a user and a directory on which to run an application? It could create the options, add the user, the directory, a group for the user... I do this for every module

## Neuron
* Add SSL options
* `Restart="always"` for `neuron` and `do-on-request`

## osTicket
* Add backup options
* Add email options
* Currently, I have a hack for `setup-users` to launch only on first boot. Manage to get ConditionFirstBoot to work in order to remove it.

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Mail/SNM
* Give it some love

## Wallabag
* `copy-wallabag` takes 5 minutes, runs out of RAM if I don't increase it. This must be a QEMU problem, I've tried all reasonable msizes to no avail so maybe it's not 9p? Nothing is mounted anyway (well, `/home` is but that shouldn't matter)
* Write parameters.yml
* Setup database
