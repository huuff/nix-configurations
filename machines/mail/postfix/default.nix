{ config, pkgs, lib, ... }:
with lib;
with (import ./postfix-lib.nix { inherit lib pkgs config; });

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

  mapType = { options, config, name, ... }: with types; {
    options = {
      name = mkOption {
        default = name;
        type = str;
        description = "Name of the map which will be on the final file";
      };

      path = mkOption {
        type = oneOf [ str path ];
        default = cfg.installation.path;
        description = "Path where the map will be put";
      };

      type = mkOption {
        type = enum [ "pcre" "hash" ];
        default = "hash";
        description = "Type of the map";
      };

      contents = mkOption {
        type = attrs;
        default = {};
        description = "Contents of the map";
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
        #"reject_non_fqdn_recipient" # TODO: FQDNs, easy way to disable this
        "reject_non_fqdn_sender"
        "reject_unknown_sender_domain"
        "reject_unknown_recipient_domain"
        "permit_mynetworks"
        "reject_unauth_destination"
        #"check_recipient_access hash:/etc/postfix/roleaccount_exceptions" # TODO: alias maps
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

        maps = mkOption {
          type = attrsOf (types.submodule mapType);
          default = {};
          description = "Maps that will be created";
        };

        canonicalDomain = mkOption {
          type = str;
          description = "Canonical domain of the server";
        };

        extraDomains = mkOption {
          type = listOf str;
          default = [];
          description = "Extra domains for which we accept mail";
        };

        mailPath = mkOption {
          type = oneOf [ str path ];
          default = "/var/lib/vmail";
          description = "Path of the virtual mailboxes";
        };

        users = mkOption {
          type = listOf str;
          default = [];
          description = "Default users to create on first setup";
        };

        mailUser = mkOption {
          type = str;
          default = "vmail";
          description = "User that will own the virtual mailbox";
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
      machines.postfix.main = {
        compatibility_level = "3.6";
        append_dot_mydomain = false; # MUA's work
        readme_directory = false;
        mydomain = cfg.canonicalDomain;

        # TODO: use null for these
        # disable local delivery for security
        mydestination = "";
        local_recipient_maps = "";
        local_transport = "error:local mail delivery is disabled";
        # TODO: isn't this $mydomain by default? Does this do anything?
        myorigin = cfg.canonicalDomain;

        # Virtual mailbox setting
        virtual_mailbox_domains = [cfg.canonicalDomain] ++ cfg.extraDomains;
        virtual_mailbox_base = cfg.mailPath;
        virtual_uid_maps = "static:${toString config.users.users.vmail.uid}";
        virtual_gid_maps = "static:${toString config.users.groups.vmail.gid}";
        virtual_mailbox_maps = mapToMain cfg.maps.virtual_mailbox_maps;

        relayhost = "";
        # TODO: Try to remove this, we only use virtual users
        alias_maps = "hash:/etc/aliases";
        alias_database = "hash:/etc/aliases";

        mynetworks = "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128";
        inet_interfaces = "all";
      } // restrictionsSets."${cfg.restrictions}";

      # Default master.cf
      machines.postfix.master = import ./master-default.nix;

      machines.postfix.maps = {
        virtual_mailbox_maps = {
          path = "${cfg.installation.path}";
          contents = mkMerge (map (vuser: { "${vuser}" = "${vuser}/";}) cfg.users);
        };
      };

      environment = {
        systemPackages = with pkgs; [ postfix ];

        etc = {
          "postfix/main.cf".source = mainCfFile;
          "postfix/master.cf".source = masterCfFile;
        };
      };

      users = {
        groups.postdrop = {};
        users."${cfg.mailUser}" = {
          isSystemUser = true;
          uid = 1000;
        };
        groups."${cfg.mailUser}" = {
          gid = 1000;
        };
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.installation.path}/queue - root root - -"
        "f /etc/aliases - root root - -"
        "L ${mapToPath cfg.maps.virtual_mailbox_maps} - ${cfg.mailUser} ${cfg.mailUser} - ${mapToFile cfg.maps.virtual_mailbox_maps}"
      ] ++ usersToTmpfiles;

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

       # TODO: This with tmpfiles
       preStart = ''
            mkdir -p /var/spool/mail
            chown root:root /var/spool/mail
            chmod a+rwxt /var/spool/mail
            ln -sf /var/spool/mail /var/
            newaliases
       '' + generateDatabases;
     };
   };
 }
