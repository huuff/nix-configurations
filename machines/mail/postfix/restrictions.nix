{ cfg, lib, postfixLib, ... }:

with lib;
with postfixLib;
with cfg.restrictions;

let
  fqdnRegex = "^([a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,63}$";
  hasFQDN = (builtins.match fqdnRegex cfg.canonicalDomain) != null;
  mkRestriction = name: switches: { inherit name switches; };

  allRestrictions = [
    (mkRestriction "reject_non_fqdn_recipient" [ rfcConformant hasFQDN ])
    (mkRestriction "reject_non_fqdn_sender" [ rfcConformant ])
    (mkRestriction "reject_unknown_sender_domain" [ rfcConformant ])
    (mkRestriction "reject_unknown_recipient_domain" [ rfcConformant ]) # Unable to test it, currently commented in the test
    (mkRestriction "permit_mynetworks" []) # Faster delivery for local machines
    (mkRestriction "reject_unauth_destination" [ noOpenRelay ])
    (mkRestriction "check_recipient_access ${mapToMain cfg.maps.permit_rfc_required_accounts}" [ rfcConformant ])
    # The following two have swapped order from what I've read, but I haven't found any
    # test hostname that passes as FQDN but is invalid. maybe look into it?
    (mkRestriction "reject_invalid_helo_hostname" [ rfcConformant ])
    (mkRestriction "reject_non_fqdn_helo_hostname" [ rfcConformant ])
    (mkRestriction "check_sender_mx_access ${mapToMain cfg.maps.bogus_mx}" [ antiForgery ])
    (mkRestriction "permit" []) # Allow anything that passed all previous restrictions
  ];
in {
  smtpd_recipient_restrictions = map (r: r.name) (filter (restriction: all (s: s) restriction.switches) allRestrictions);
}
