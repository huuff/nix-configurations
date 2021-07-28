# TODO
* Maybe Zammad? osTicket seems dated
* For all systemd services: Put description in the outermost block instead of `unitConfig`

## Neuron
* Add SSL options

## osTicket
* Add backup options
* Add email options
* Why is multi-user target reached before having run my systemd units? but only on some computers? a complete mystery
* Currently, I have a hack for `setup-users` to launch only on first boot. Manage to get ConditionFirstBoot to work in order to remove it.

## Jenkins
* Set up JDKs (in `configuration.xml`)
* Set up credentials (in `credentials.xml`)
* Set up security

## Mail/SNM
* Give it some love

