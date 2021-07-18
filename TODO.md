# TODO
* Maybe these should be modules with options and all instead of functions? It would make them much more versatile
* Maybe Zammad? osTicket seems dated

## Neuron
* Add SSL options

## osTicket
* Still can't enter localhost:8989/scp (Or more explicitly: it doesn't redirect me to scp/admin.php)
* Add SSL options
* Add backup options
* Go to scp, hit New Ticket. A modal fails to appear and I'm sure it's some nginx stuff
* Definitely needs to be a module and set all osTicket installation options as module options
* Add descriptions to services

### initial-script.sql
osTicket needs a mysql user identified by a password, the NixOS module won't let us do this through config since that password would be in cleartext in the nix-store, so we need to pass it a file. 

However, this file can't be in the store or else the same problem would ensue! This means this file must be added extraneously, but still, it's very much part of the configuration.

Some solutions that might be worth of looking into:
* Putting all the script in the store but the password outside of it? most likely impossible, since the password must be text inside the file
* Maybe look into agenix.
