{ config, pkgs, lib, ... }:
with lib;
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

  boolToYN = bool: if bool then "y" else "n";

  boolToYesNo = bool: if bool then "yes" else "no";

  wakeupToStr = wakeup: if (wakeup == null) then "never" else (toString wakeup);

  mainAttrToStr = value: if (builtins.typeOf value == "bool") then (boolToYesNo value) else (toString value);

  attrsToMainCf = name: value: "${name} = ${mainAttrToStr value}";

  # TODO: A concatStringsSep with this and spaces (or tabs) and a list for the strings.
  attrsToMasterCf = name: value: "${if (value.name == null) then name else value.name} ${value.type} ${boolToYN value.private} ${boolToYN value.unpriv} ${boolToYN value.chroot} ${wakeupToStr value.wakeup} ${toString value.maxproc} ${value.command} ${concatStringsSep " " value.args}";
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
      # TODO: Default main.cf
      # TODO: Find out what these mean exactly
      machines.postfix.main = {
        biff = false;
        mailbox_size_limit = 0;
        recipient_delimiter = "+";
        readme_directory = false;
        myhostname = "nixos"; # TODO: Actual hostname
        mydestination = "localhost"; #TODO: Actual destination
        append_dot_mydomain = false;
        relayhost = "";
        alias_maps = "hash:/etc/aliases";
        alias_database = "hash:/etc/aliases";
        mynetworks = "127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128";
        inet_interfaces = "all";
      };

      # TODO: I'm sure I don't need all this shit
      # Default master.cf
      machines.postfix.master = {
        smtpd = {
          type = "inet";
          private = false;
          chroot = false;
          command = "smtpd";
          name = "smtp";
        };

        pickup = {
          type = "unix";
          private = false;
          chroot = false;
          wakeup = 60;
          maxproc = 1;
          command = "pickup";
        };

        cleanup = {
          type = "unix";
          private = false;
          chroot = false;
          maxproc = 0;
          command = "cleanup";
        };

        qmgr = {
          type = "unix";
          private = false;
          chroot = false;
          wakeup = 300;
          maxproc = 1;
          command = "qmgr";
        };

        tlsmgr = {
          type = "unix";
          maxproc = 1;
          chroot = false;
          wakeup = 1000;
          command = "tlsmgr";
        };

        rewrite = {
          type = "unix";
          chroot = false;
          command = "trivial-rewrite";
        };

        bounce = {
          type = "unix";
          chroot = false;
          maxproc = 0;
          command = "bounce";
        };

        defer = {
          type = "unix";
          chroot = false;
          maxproc = 0;
          command = "bounce";
        };

        trace = {
          type = "unix";
          chroot = false;
          maxproc = 0;
          command = "bounce";
        };

        verify = {
          type = "unix";
          chroot = false;
          maxproc = 1;
          command = "verify";
        };

        flush = {
          type = "unix";
          private = false;
          maxproc = 0;
          chroot = false;
          wakeup = 1000;
          command = "flush";
        };

        proxymap = {
          type = "unix";
          chroot = false;
          command = "proxymap";
        };

        proxywrite = {
          type = "unix";
          chroot = false;
          command = "proxywrite";
        };

        smtp = {
          type = "unix";
          chroot = false;
          command = "smtp";
        };

        relay = {
          type = "unix";
          chroot = false;
          command = "smtp";
        };

        showq = {
          type = "unix";
          private = false;
          chroot = false;
          command = "showq";
        };

        error = {
          type = "unix";
          chroot = false;
          command = "error";
        };

        retry = {
          type = "unix";
          chroot = false;
          command = "error";
        };

        discard = {
          type = "unix";
          chroot = false;
          command = "discard";
        };

        local = {
          type = "unix";
          unpriv = false;
          chroot = false;
          command = "local";
        };

        virtual = {
          type = "unix";
          unpriv = false;
          chroot = false;
          command = "virtual";
        };

        lmtp = {
          type = "unix";
          chroot = false;
          command = "lmtp";
        };

        anvil = {
          type = "unix";
          chroot = false;
          maxproc = 1;
          command = "anvil";
        };

        scache = {
          type = "unix";
          chroot = false;
          maxproc = 1;
          command = "scache";
        };
      };

      environment = {

        systemPackages = with pkgs; [ postfix ];

        etc = {
          "postfix/main.cf".source = mainCfFile;
          "postfix/master.cf".source = masterCfFile;
        };
      };

      users.groups.postdrop = {};

      services.ensurePaths = 
      let
        installation = config.machines.postfix.installation;
      in
      [
        { path = "${installation.path}/queue"; owner = "root"; }
        "/etc/aliases"
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
  }
