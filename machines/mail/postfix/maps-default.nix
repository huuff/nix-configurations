{ cfg, lib, ... }:
with lib;
{
  virtual_mailbox_maps = {
    contents = (mkMerge (map (vuser: { "${vuser}" = "${vuser}/";}) cfg.users));
  };

  # We should always accept these for RFC conformance
  permit_rfc_required_accounts = {
    contents = {
      "postmaster@${cfg.canonicalDomain}" = "OK";
      "abuse@${cfg.canonicalDomain}" = "OK";
    };

    addToMain = false;
  };

  helo_checks = {
    type = "pcre";
    contents = [
      { "/^${builtins.replaceStrings [ "." ] [ "\\." ] cfg.main.myhostname}$/" = "550 Don't use my hostname"; }
      { "/^[0-9.]+$/" = "550 Your client is not RFC 2821 compliant"; }
    ];

    addToMain = false;
  };

  bogus_mx = {
    type = "cidr";
    contents = {
      "0.0.0.0/8" = "550 Mail server in broadcast network";
      "10.0.0.0/8" = "550 No route to your RFC 1918 network";
      "127.0.0.0/8" = "550 Mail server in loopback network";
      "224.0.0.0/4" = "550 Mail server in class D multicast network";
      "192.168.0.0/16" = "550 No route to your RFC 1918 network";
    };
    addToMain = false;
  };

  rbl_exceptions = {
    contents = mkMerge (map (exception: { ${exception} = "OK"; }) cfg.restrictions.dnsBlocklists.clientExceptions);
    addToMain = false;
  };

  rhsbl_exceptions = {
    contents = mkMerge (map (exception: { ${exception} = "OK"; }) cfg.restrictions.dnsBlocklists.senderExceptions);
    addToMain = false;
  };

  # For selective sender verification
  common_spam_senderdomains = {
    contents = mkMerge (map (domain: { ${domain} = "reject_unverified_sender"; }) cfg.restrictions.verifyDomains);
    addToMain = false;
  };
}
