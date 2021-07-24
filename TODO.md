# TODO
* NixOS testing? [https://nixos.org/#asciinema-demo-example_6](check this out), [https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests](and this)
* Maybe Zammad? osTicket seems dated

## Neuron
* Add SSL options
* Add the password option since I'm using it in my personal instance and doesn't seem like a bad idea
* Make it a module instead of a function

## osTicket
* Still can't enter localhost:8989/scp (Or more explicitly: it doesn't redirect me to scp/admin.php)
* Add SSL options
* Add backup options
* Why is multi-user target reached before having run my systemd units? but only on some computers? a complete mystery
* Remove null defaults
* Add assertions for nulls, especially those interpolated into strings since these just appear as ""
* `setup-users` gets run on every activation which is not optimal

### SQL as root
Currently I'm running all SQL as root because I can easily login through unix socket with it. However, this is suboptimal (maybe not, but I want to stop doing it anyway).

What can I do?
* Does the `mysql` user work for this? (I think not)
* What about giving osticket user unix socket access?
* Catting the db user password in the script? It doesn't seem like a bad idea actually, almost everything is done that way.

## Mail/SNM
* Give it some love

