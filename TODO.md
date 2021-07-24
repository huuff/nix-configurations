# TODO
* NixOS testing? [https://nixos.org/#asciinema-demo-example_6](check this out), [https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests](and this)
* Maybe Zammad? osTicket seems dated

## Neuron
* Add SSL options
* Make it a module instead of a function

## osTicket
* Still can't enter localhost:8989/scp (Or more explicitly: it doesn't redirect me to scp/admin.php)
* Add SSL options
* Add backup options
* Set some options to add default users and put these into the database
* Why is multi-user target reached before having run my systemd units? but only on some computers? a complete mystery
* Move what I use for testing to an `example` folder
* Remove null defaults
* Add assertions for nulls, especially those interpolated into strings since these just appear as ""

### initial-script.sql
osTicket needs a mysql user identified by a password, the NixOS module won't let us do this through config since that password would be in cleartext in the nix-store, so we need to pass it a file. 

However, this file can't be in the store or else the same problem would ensue! This means this file must be added extraneously, but still, it's very much part of the configuration.

Some solutions that might be worth of looking into:
* Putting all the script in the store but the password outside of it? most likely impossible, since the password must be text inside the file
* Maybe look into agenix.

UPDATE: Okay, my action plan:
* I have created a systemd service that creates the database and the user, get the user password from a file that can be passed as an option so it's taken from outside of the nix store. (DONE)
* Then, using more or less the same process, create another systemd unit that populates the database with some default users, my idea for that:
* Put these into a JSON, stating only username and password, read through it and convert it to sql, but substitute the contents of the json only using bash (not nix, and thus, it won't get into the nix store)
* Then, this JSON file path could be passed as an option to the module

This process is kinda extenuating, and reinforces the idea that Nix needs some form of secret management

UPDATE2:
The file for users is on, it's currently taking the password for the admin user (TODO: also the email, name, etc). It's not yet done for the rest of users.

A challenge: the root user password is entered unhashed (it's how the install script takes it), however, those for normal users will need to be hashed (since they will be entered into the DB directly). How can I marry these two requisites?

* Maybe enter some default admin user password first unhashed, and then alter the database to put it hashed from userfile?

UPDATE3:
Okay, I just noticed that putting all user config into a JSON is pretty crazy, it would need to be consumed by bash since otherwise, it would end in the nix store and fuck our security constraints.

Since it would need to be consumed by bash, we couldn't use any of nix power for it and thus the result would be an unsightly mix of bash + nix.

Next idea: Only put passwords in files, and specify the files in the config. Nothing else. This will make it much simpler.

## Mail/SNM
* Give it some love

