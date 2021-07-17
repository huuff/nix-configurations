# TODO
* Maybe these should be modules with options and all instead of functions? It would make them much more versatile
* osTicket forces users to install through a GUI, so it's not very suitable for Nix. Maybe use zammad

## Neuron
* Add SSL options

## osTicket
* Does changing ost-config.php to put database info help in any way? Crazy idea: run a headless browser and fill in the form automatically on activation
* Add SSL options
* Add backup options

### initial-script.sql
osTicket needs a mysql user identified by a password, the NixOS module won't let us do this through config since that password would be in cleartext in the nix-store, so we need to pass it a file. 

However, this file can't be in the store or else the same problem would ensue! This means this file must be added extraneously, but still, it's very much part of the configuration.

Some solutions that might be worth of looking into:
* Putting all the script in the store but the password outside of it? most likely impossible, since the password must be text inside the file
* Maybe look into agenix.
