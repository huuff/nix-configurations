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

## Mail/SNM
* Give it some love

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
