## Neuron
* Use a systemd user oneshot script to initialize directory (check home-manager/nixos). Or maybe not? I'm not sure oneshot is for this
* Make user configurable. Or not? I don't really care
* Add SSL options

## osTicket
* The initial script (mysql) only seems to get executed if inlined, try to get it to work without putting it into the nix store
* APCu extension? supposedly that makes it faster
* Copy include/ost-sampleconfig.php to include/ost-config.php and chmod it to 666. Does it change anything if I put the database info there? Doesn't seem like it
* Add SSL options
* Add backup options
