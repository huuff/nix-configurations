{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.machines.postfix;
in
  {

  imports = [
    (import ../../lib/mk-installation-module.nix "postfix")
  ];

  options = {
    machines.postfix = {
      enable = mkEnableOption "Postfix SMTP server";
    };
  };
  
  config =
  let
    defaultMainCf = pkgs.writeText "main.cf" ''
      smtpd_banner = $myhostname ESMTP $mail_name (Ubuntu)
      biff = no

      # appending .domain is the MUA's job.
      append_dot_mydomain = no

      # Uncomment the next line to generate "delayed mail" warnings
      #delay_warning_time = 4h

      readme_directory = no

      # TLS parameters
      smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
      smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
      smtpd_use_tls=yes
      smtpd_tls_session_cache_database = btree:''${data_directory}/smtpd_scache
      smtp_tls_session_cache_database = btree:''${data_directory}/smtp_scache

      # See /usr/share/doc/postfix/TLS_README.gz in the postfix-doc package for
      # information on enabling SSL in the smtp client.

      # TODO: Actual hostname
      myhostname = nixos
      alias_maps = hash:/etc/aliases
      alias_database = hash:/etc/aliases
      myorigin = /etc/mailname
      mydestination = localhost
      relayhost =
      mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
      mailbox_size_limit = 0
      recipient_delimiter = +
      inet_interfaces = all
    '';
    defaultMasterCf = pkgs.writeText "master.cf" ''
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (no)    (never) (100)
# ==========================================================================
smtp      inet  n       -       n       -       -       smtpd
#submission inet n       -       n       -       -       smtpd
pickup    unix  n       -       n       60      1       pickup
cleanup   unix  n       -       n       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
tlsmgr    unix  -       -       n       1000?   1       tlsmgr
rewrite   unix  -       -       n       -       -       trivial-rewrite
bounce    unix  -       -       n       -       0       bounce
defer     unix  -       -       n       -       0       bounce
trace     unix  -       -       n       -       0       bounce
verify    unix  -       -       n       -       1       verify
flush     unix  n       -       n       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       n       -       -       smtp
relay     unix  -       -       n       -       -       smtp
showq     unix  n       -       n       -       -       showq
error     unix  -       -       n       -       -       error
retry     unix  -       -       n       -       -       error
discard   unix  -       -       n       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       n       -       -       lmtp
anvil     unix  -       -       n       -       1       anvil
scache    unix  -       -       n       -       1       scache
  '';
  in
  {
    environment = {
      systemPackages = with pkgs; [ postfix ];

      etc = {
        "postfix/main.cf".source = defaultMainCf;
        "postfix/master.cf".source = defaultMasterCf;
      };
    };

    machines.ensurePaths = [
      { path = "${cfg.installation.path}/queue"; owner = cfg.installation.user; }
      "/etc/aliases"
    ];

    # Required for setgid_group
    users.groups.postdrop = {};

    systemd.services = {
      postfix = {
        description = "Postfix SMTP server";

        path = [ pkgs.postfix ];

        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "ensure-paths.service" ];

        serviceConfig = {
          Type = "forking";
          Restart = "always";
          ExecStart = "${pkgs.postfix}/bin/postfix start";
          ExecStop = "${pkgs.postfix}/bin/postfix stop";
          ExecReload = "${pkgs.postfix}/bin/postfix reload";
        };

        preStart = ''
            mkdir -p /var/spool/mail
            chown root:root /var/spool/mail
            chmod a+rwxt /var/spool/mail
            ln -sf /var/spool/mail /var/
            newaliases
          '';
      };
    };
  };
}
