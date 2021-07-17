# TODO
* osTicket forces users to install through a GUI, so it's not very suitable for Nix. Maybe use zammad

## Neuron
* Use a systemd user oneshot script to initialize directory (check home-manager/nixos). Or maybe not? I'm not sure oneshot is for this
* Add SSL options

## osTicket
* The initial script (mysql) only seems to get executed if inlined, try to get it to work without putting it into the nix store
* APCu extension? supposedly that makes it faster
* Does changing ost-config.php to put database info help in any way?
* Add SSL options
* Add backup options
* Can't enter admin panel! (/scp). It redirects to https so maybe I must set a certificate?Update: Welp, I actually can (http://localhost:8989/scp/login.php). But why does it redirect me to https?
* My oneshot systemd unit runs on every activation, so it ruins everything.
