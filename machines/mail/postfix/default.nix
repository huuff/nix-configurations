{ config, pkgs, lib, ... }:
with lib;

let
  cfg = config.machines.postfix;

  postfixLib = import ./postfix-lib.nix { inherit lib pkgs cfg; };

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
        type = enum [ "pcre" "hash" "cidr" ];
        default = "hash";
        description = "Type of the map";
      };

      contents = mkOption {
        type = oneOf [ attrs (listOf attrs) ];
        default = {};
        description = "Contents of the map";
      };

      addToMain = mkOption {
        type = bool;
        default = true;
        description = "Automatically add this map to main.cf";
      };
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

        restrictions = {
          noOpenRelay = mkOption {
            type = bool;
            default = true;
            description = "The bare minimum of restriction to avoid being an open relay. Disable only in testing";
          };

          rfcConformant = mkOption {
            type = bool;
            default = true;
            description = "Enforce clients to follow RFC specifications";
          };

          antiForgery = mkOption {
            type = bool;
            default = true;
            description = "Reject our address and bogus nameserver records";
          };

          noMultiRecipientBounce = mkOption {
            type = bool;
            default = true;
            description = "Reject messages from the empty sender to multiple recipients";
          };

          alwaysVerifySender = mkEnableOption "verify every sender";

          selectiveSenderVerification = mkEnableOption "verify senders in verifyDomains";

          verifyDomains = mkOption {
            type = listOf str;
            default = [ "hotmail.com" ];
            description = "Domains to verify selectively";
          };

          dnsBlocklists = {
            enable = mkEnableOption "DNS blocklists";

            client = mkOption {
              type = listOf str;
              default = [ "zen.spamhaus.org=127.0.0.[2..11]" ];
              description = "DNS blacklists to add to reject_rbl_client"; 
            };

            clientExceptions = mkOption {
              type = listOf str;
              default = [];
              description = "List of exceptions to the client DNS blocklist";
            };

            sender = mkOption {
              type = listOf str;
              default = [];
              description = "DNS blacklists to add to reject_rhsbl_sender";
            };

            senderExceptions = mkOption {
              type = listOf str;
              default = [];
              description = "Exceptions to the sender DNS blocklist";
            };
          };
        };
      };
    };

    config =
      with postfixLib;
      {

        assertions = [
          {
            assertion = cfg.restrictions.selectiveSenderVerification -> !cfg.restrictions.alwaysVerifySender;
            message = "You can't set verifyDomains if you set alwaysVerifySender";
          }
        ];

        networking.firewall.allowedTCPPorts = [ 25 ];

        machines.postfix = {
          main = import ./main-default.nix { inherit config lib postfixLib; };
          master = import ./master-default.nix;
          maps = import ./maps-default.nix { inherit cfg lib; };
          users = [
            "postmaster@${cfg.canonicalDomain}"
            "abuse@${cfg.canonicalDomain}"
          ];
        };

    environment = {
      systemPackages = with pkgs; [ postfix ];

      etc =
        let
        # TODO: Postfix sends to append something at the end, so I add a newline so it doesn't get
        # mixed with my set, however, I should prevent postfix from doing that (is that what the official nixos module does?
        mainCfFile = pkgs.writeText "main.cf" ((concatStringsSep "\n" (mapAttrsToList (attrsToMainCf) cfg.main)) + "\n");
        masterCfFile = pkgs.writeText "master.cf" (concatStringsSep "\n" (mapAttrsToList (attrsToMasterCf) cfg.master));
        in
        {
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
          "d /var/spool/mail 1777 root root - -"
          "L /var/vail - - - - /var/spool/mail"
        ]
        ++ mapsToTmpfiles
        ++ createMailboxes  
        ;

     # TODO: Make this unneeded by removing sendmail from all tests (use telnet)
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
            newaliases
       '' + generateDatabases;
     };
   };
 }
