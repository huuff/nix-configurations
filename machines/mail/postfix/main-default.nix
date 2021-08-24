{ config, lib, postfixLib, ... }:

with lib;
with postfixLib;

let
  cfg = config.machines.postfix;
in
{
  compatibility_level = "3.6";
  append_dot_mydomain = false; # MUA's responsibility
  readme_directory = false;
  mydomain = cfg.canonicalDomain;
  myhostname = "${config.networking.hostName}.${cfg.canonicalDomain}";

  # Disable local delivery for security
  mydestination = null;
  local_recipient_maps = null;
  local_transport = "error:local mail delivery is disabled";
  myorigin = cfg.canonicalDomain;

  # Virtual mailbox setting
  virtual_mailbox_domains = [cfg.canonicalDomain] ++ cfg.extraDomains;
  virtual_mailbox_base = cfg.mailPath;
  virtual_uid_maps = "static:${toString config.users.users.${cfg.mailUser}.uid}";
  virtual_gid_maps = "static:${toString config.users.groups.${cfg.mailUser}.gid}";

  relayhost = "";

  # This will help prevent address scanning
  disable_vrfy_command = true;

  mynetworks = "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128";
  inet_interfaces = "all";
}
  // optionalAttrs (cfg.restrictions.rfcConformant) { smtpd_helo_required = true; }
  // optionalAttrs (cfg.restrictions.noMultiRecipientBounce) { smtpd_data_restrictions = "reject_multi_recipient_bounce"; }
  // mapAttrs (name: value: mapToMain value) (filterAttrs (_: pfMap: pfMap.addToMain) cfg.maps)
  // import ./restrictions.nix { inherit cfg lib postfixLib; }

