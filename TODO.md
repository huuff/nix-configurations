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
* Add email options
* Why is multi-user target reached before having run my systemd units? but only on some computers? a complete mystery
* `setup-users` gets run on every activation which is not optimal

### Assertions
Find out which configuration options need to be set and which values must be specified and add assertions for them.

Find out which configs are not needed, maybe set up some way so they are not set at all.

* Every email is needed, maybe even check if it's an email? (UPDATE: Definitely not checking if they are emails)
* username is not required for users.
* Are admin first and last name required?

## Mail/SNM
* Give it some love

