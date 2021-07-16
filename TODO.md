## Neuron
* Use a systemd user oneshot script to initialize directory (check home-manager/nixos). Or maybe not? I'm not sure oneshot is for this
* Make user configurable. Or not? I don't really care
* Add SSL options

## osTicket
* The initial script (mysql) only seems to get executed if inlined, try to get it to work without putting it into the nix store
* APCu extension? supposedly that makes it faster
* Does changing ost-config.php to put database info help in any way?
* Add SSL options
* Add backup options
