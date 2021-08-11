# TODO
* Maybe Zammad? osTicket seems dated
* A module or library for `PHP` + `nginx`, but I find it difficult since I just copypaste nginx configurations from the internet.
* I'm making some efforts to get these to work for an installation with multiple modules at the same time, but does it? I've never tested.
* In `osTicket` and `wallabag`, is there any way I can test that users can login? Maybe I need to automate the browser?
* Realized I fucked up by using the `services` namespace. I can't override its modules comfortable because it fucks a lot of stuff up (my first try was to disable the modules I overrided, but then I had to disable any that depended on them and then just about everything went wrong). Move everything to `machines` which is going to be exhausting. UPDATE: Crisis averted? The `machines` namespace looks a bit weird. I realize that maybe, my lib modules should be on `services` and my machines in `machines` since the lib modules are general purpose and usually not really useful by themselves? Or maybe another namespace is needed. Wish Nix made this easier.
* I think I've used `mkEnableOption` wrong every single time. It takes a name, not a description.

## Neuron
* Finish test. UPDATE: Test that it actually is pulled on a request to `refreshPort`. But how? I can make the request but I don't know how to check it it's pulling. UPDATE: Redirecting the `doOnRequest` log to somewhere and reading it? UPDATE: Is it still necessary? I've tested `doOnRequest` after all. UPDATE: Yeah but these are integration tests and testing the individual components does not guarantee that they all work together

## osTicket
* Add backup options
* Add email options
* A config object, and transform it to the `curl` request (same as for `parameters.yml` in `wallabag`)

## Jenkins
* ON HOLD. I want to use `withCLI` in the Jenkins module of nixpkgs but it's not available in my version yet. Wait until it's stable? bump to 21.11pre? I realize I know nothing about the nixpkgs release scheme. UPDATE: Maybe just implement the module myself, there's a good chance I'll have to anyway
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Wallabag
* `copy-wallabag` is really slow on some computers, is it a KVM thing?
* Backup options, there's nothing yet but it's pretty important
* Add email options
* Seems like `create-parameters` should be an external file, it takes too much space. UPDATE: What about making it an attribute set and using `toYAML`?

### Auto-import
It works, but:
* REMEMBER TO ENABLE IT IN THE DB! But do it tomorrow. It's late now.
* Seems like `redis` needs write access, but the NixOS module doesn't add any `mkOverride` so I can't give it that. So maybe I'll need to also implement my own `redis` module.
* Since I'm at it, I could implement also `rabbitmq`
* Implement other imports? not only `pocket`? Though I don't use them, I'd never know.

## mkInitModule
* Add an intermediate "lock" for each unit, so these can show at what point of the initialization we are, and thus, restart from an intermediate point instead of from the beginning.
* Make it somewhat more terse. My init scripts still look a bit hideous

## mkInstallationModule
* Allow to define a group, maybe extra groups, for `postdrop` for example.

## ensurePaths
* Add option to ensure paths based on installation

## mkDatabaseModule
* Add `postgres`
* Maybe add also socket access to users, not only password, so I don't have to use the password in each `exec` SQL.

## mkSSLModule
* Option to add own certificate
* Option to generate one from Let's Encrypt
* Check and generate certificates if they are expired
* Definitely needs to follow the path convention

## Mail
* Took into the absurd endeavour of implementing my own mail server in Nix, not without copying chunks of code from `nixpkgs` or `snm`, of course. I decided to begin little by little, with a module for `postfix`, `dovecot`, `roundcube`, etc..

### Postfix
* Mostly everything really
* Test it. For starters, that I can write a mail from root to root and get it.
* Try to get it to work for several users and see what happens, maybe test if they get the mails.
* Add aliases
* Make some substitutions in the config
