{ config, pkgs, lib, ... }:
with lib;
with (import ./postfix-lib.nix { inherit lib; });

let
  cfg = config.machines.postfix;
  masterEntryModule = with types; submodule {
    options = {
      type = mkOption {
        type = enum [ "inet" "unix" ];
        description = "Type of the service";
      };

      private = mkOption {
        type = bool;
        default = true;
        description = "TODO: Find what this is about";
      };

      unpriv = mkOption {
        type = bool;
        default = true;
        description = "TODO: I think I know what this is about but look it up";
      };

      chroot = mkOption {
        type = bool;
        default = false;
        description = "TODO";
      };

      wakeup = mkOption {
        type = int;
        default = 0; # TODO: What is the question mark?
        description = "TODO";
      };

      maxproc = mkOption {
        type = int;
        default = 100;
        description = "TODO";
      };

      command = mkOption {
        type = str;
        description = "TODO";
      };

      args = mkOption {
        type = listOf str;
        default = [];
        description = "TODO";
      };

      # HACK: I would like to have a better solution, and the one by the official module is pretty good. Or maybe this isn't that bad? They have an extra option just for the name anyway.
      name = mkOption {
        type = nullOr str;
        default = null;
        description = "Name for the service, only for when there are collisions (such as smtpd and smtp having the same name";
      };
    };
  };

  restrictionsSets = {
    none = {
      smtpd_recipient_restrictions = [];
    };

    no_open_relay = {
      smtpd_recipient_restrictions = [
        "permit_mynetworks"
        "reject_unauth_destination"
        "permit"
      ];
    };

    rfc_conformant = {
      smtpd_helo_required = true;
      
      smtpd_recipient_restrictions = [
        "reject_non_fqdn_recipient"
        "reject_non_fqdn_sender"
        "reject_unknown_sender_domain"
        "reject_unknown_recipient_domain"
        "permit_mynetworks"
        "reject_unauth_destination"
        #"check_recipient_access hash:/etc/postfix/roleaccount_exceptions"
        "reject_non_fqdn_hostname"
        "reject_inavlid_hostname"
        "permit"
      ];
    };
  };

in
  {
    imports = [
      (import ../../../lib/mk-installation-module.nix "postfix")
    ];

    options = {
      machines.postfix = with types; {
        enable = mkEnableOption "postfix";

        main = mkOption {
          type = attrs;
          default = {};
          description = "The contents of the main.cf file as an attribute set";
        };

        master = mkOption {
          type = attrsOf masterEntryModule;
          default = {};
          description = "The contents of the master.cf file as an attribute set";
        };

        restrictions = mkOption {
          type = enum (attrNames restrictionsSets);
          default = "no_open_relay";
          description = "Set of restrictions to enable in increasing order of complexity";
        };

      };
    };

    config =
      let
        # TODO: Postfix sends to append something at the end, so I add a newline so it doesn't get
        # mixed with my set, however, I should prevent postfix from doing that (is that what the official nixos module does?
        mainCfFile = pkgs.writeText "main.cf" ((concatStringsSep "\n" (mapAttrsToList (attrsToMainCf) cfg.main)) + "\n");
        masterCfFile = pkgs.writeText "master.cf" (concatStringsSep "\n" (mapAttrsToList (attrsToMasterCf) cfg.master));
      in
      {
      # TODO: Find out what these mean exactly
      machines.postfix.main = {
        append_dot_mydomain = false;
        biff = false;
        mailbox_size_limit = 0;
        recipient_delimiter = "+";
        readme_directory = false;
        myhostname = "nixos"; # TODO: Actual hostname
        mydestination = "localhost"; #TODO: Actual destination
        relayhost = "";
        alias_maps = "hash:/etc/aliases";
        alias_database = "hash:/etc/aliases";
        mynetworks = "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128";
        inet_interfaces = "all";
      } // restrictionsSets."${cfg.restrictions}";

      # TODO: I'm sure I don't need all this shit
      # Default master.cf
      machines.postfix.master = import ./master-default.nix;

      environment = {

        systemPackages = with pkgs; [ postfix ];

        etc = {
          "postfix/main.cf".source = mainCfFile;
          "postfix/master.cf".source = masterCfFile;
        };
      };

      users.groups.postdrop = {};

      systemd.tmpfiles.rules = [
        "d ${cfg.installation.path}/queue - root root - -"
        "f /etc/aliases - root root - -"
      ];

     # TODO: What's this? 
      services.mail.sendmailSetuidWrapper = mkIf config.services.postfix.setSendmail {
        program = "sendmail";
        source = "${pkgs.postfix}/bin/sendmail";
        group = "postdrop";
        setuid = false;
        setgid = true;
      };

      systemd.services.postfix = {
        description = "Postfix SMTP server";

        path = [ pkgs.postfix ];

        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

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
  }
