{ config, lib, postfixLib, ... }:

with lib;
with postfixLib;

let
  cfg = config.machines.postfix;
in
{
  compatibility_level = "3.6";
  append_dot_mydomain = false; # MUA's work
  readme_directory = false;
  mydomain = cfg.canonicalDomain;
  myhostname = "${config.networking.hostName}.${cfg.canonicalDomain}";

  # TODO: use null for these
  # disable local delivery for security
  mydestination = "";
  local_recipient_maps = "";
  local_transport = "error:local mail delivery is disabled";
  myorigin = cfg.canonicalDomain;

  # Virtual mailbox setting
  virtual_mailbox_domains = [cfg.canonicalDomain] ++ cfg.extraDomains;
  virtual_mailbox_base = cfg.mailPath;
  virtual_uid_maps = "static:${toString config.users.users.vmail.uid}";
  virtual_gid_maps = "static:${toString config.users.groups.vmail.gid}";
  #virtual_mailbox_maps = mapToMain cfg.maps.virtual_mailbox_maps;

  relayhost = "";
  # TODO: Try to remove this, we only use virtual users
  alias_maps = "hash:/etc/aliases";
  alias_database = "hash:/etc/aliases";

  mynetworks = "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128";
  inet_interfaces = "all";
}
  // optionalAttrs (cfg.restrictions.rfcConformant) { smtpd_helo_required = true; }
  // optionalAttrs (cfg.restrictions.noMultiRecipientBounce) { smtpd_data_restrictions = "reject_multi_recipient_bounce"; }
  // mapAttrs (name: value: mapToMain value) (filterAttrs (_: pfMap: pfMap.addToMain) cfg.maps)
  // import ./restrictions.nix { inherit cfg lib postfixLib; }

