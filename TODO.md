# TODO
* Maybe Zammad? osTicket seems dated
* What about a library for setting a user and a directory on which to run an application? It could create the options, add the user, the directory, a group for the user... I do this for every module
* A module or library for PHP + nginx, but I find it difficult since I just copypaste nginx configurations from the internet.

## Neuron
* Add SSL options
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling

## osTicket
* Add backup options
* Add email options
* Save passwords in plaintext, then hash them before adding to DB to remove user effort. They can still be protected with `agenix` or `sops-nix`
* Currently, I have a hack for `setup-users` to launch only on first boot. Manage to get `ConditionFirstBoot` to work in order to remove it.
* Add more tests. I'm genuinely scared I'll break it.
* In my example, is my `fileFromStore` function actually useful? Can't I just reference a file and `nixos-shell` copy it into the VM? Check it. UPDATE: It works without for wallabag but not for osTicket? (Gives permission denied) What gives?

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Wallabag
* `copy-wallabag` is really slow on some computers, is it a KVM thing?
* Backup options, there's nothing yet but it's pretty important
* Get `install-wallabag` to run only on first boot
* SSL option
* It's definitely time to look into secret management tools like `sops` or `agenix` because I'm deploying user passwords in plaintext. Inserting them directly into the database seems hard because I don't unserstand the `roles` table. Also this would allow me to send passwords without hashing and still being secure, which would help me standarize password management across modules
* What about auto-importing pocket?

## Mail/SNM
* Give it some love
