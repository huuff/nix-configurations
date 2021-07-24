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

## Mail/SNM
* Give it some love

