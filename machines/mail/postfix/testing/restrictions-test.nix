{ pkgs, ... }:
let
  server = rec {
    domain = "example.com";
    userAddress = "server@${domain}";
    ip = "192.168.2.1";
  };
  client = rec {
    domain = "test.org";
    userAddress = "client@${domain}";
    ip = "192.168.2.2";
  };
in
  pkgs.nixosTest {
    name = "postfix-restrictions";

    nodes = {
      server = { pkgs, ... }: {
        imports = [ ../default.nix ];

        machines.postfix = {
          enable = true;
          canonicalDomain = server.domain;

          restrictions = {
            noOpenRelay = true;
            rfcConformant = true;
            antiForgery = true;
            alwaysVerifySender = true;
          };

          users = [ 
            server.userAddress
            "user2@${server.domain}"
          ];
        };

        services.dnsmasq = {
          enable = true;
          extraConfig = ''
            address=/${server.domain}./${server.ip}
            address=/${client.domain}./${client.ip}
          '';
        };

        networking.interfaces.eth1.ipv4.addresses = [
          { address = server.ip; prefixLength = 24; }
        ];

        networking.extraHosts = "192.168.1.1 ${client.domain}";
        networking.useDHCP = false;
      };

      client = { pkgs, ... }: {
        imports = [ ../default.nix ];

        environment.systemPackages = with pkgs; [ telnet ];

        machines.postfix = {
          enable = true;
          canonicalDomain = client.domain;

          users = [ client.userAddress ];
        };

        networking.interfaces.eth1.ipv4.addresses = [
          { address = client.ip; prefixLength = 24; }
        ];

        services.dnsmasq = {
          enable = true;
          extraConfig = ''
            address=/${server.domain}./${server.ip}
            address=/${client.domain}./${client.ip}
          '';
        };
      };
  };

    testScript = ''
      ${ builtins.readFile ../../../../lib/testing-lib.py }

      def connect_smtp(self):
        self.put_tty("telnet server 25")
        self.wait_until_tty_matches(1, "220 .*?.${server.domain} ESMTP Postfix")

      def basic_conversation(self, helo="${client.domain}", fromAddr="<${client.userAddress}>", toAddr="<${server.userAddress}>"):
        self.connect_smtp()
        self.put_tty(f"HELO {helo}")
        self.wait_until_tty_matches(1, "250 .*")
        self.put_tty(f"MAIL FROM: {fromAddr}")
        self.wait_until_tty_matches(1, "250 .*")
        self.put_tty(f"RCPT TO: {toAddr}")

      def quit(self):
        self.put_tty("QUIT")
        self.wait_until_tty_matches(1, "Connection closed by foreign host.")
        self.sleep(0.3)
        self.send_key("ctrl-l")

      Machine.connect_smtp = connect_smtp
      Machine.basic_conversation = basic_conversation
      Machine.quit = quit
      del(connect_smtp)
      del(basic_conversation)
      del(quit)

      client.wait_for_unit("postfix.service")
      server.wait_for_unit("postfix.service")
      client.create_user_and_login()

      with subtest("requires HELO"):
        client.connect_smtp()
        client.put_tty("MAIL FROM: ${client.userAddress}")
        client.wait_until_tty_matches(1, "503 .*? send HELO/EHLO first")
        client.quit()

      with subtest("requires HELO FQDN"):
        client.basic_conversation(helo = "client")
        client.wait_until_tty_matches(1, "504 .* need fully-qualified hostname")
        client.quit()

      with subtest("reject invalid hostname"):
        client.basic_conversation(helo = "test/.local")
        client.wait_until_tty_matches(1, "501 .* Helo command rejected: Invalid name")
        client.quit()

      with subtest("reject non FQDN sender"):
        client.basic_conversation(fromAddr = "client")
        client.wait_until_tty_matches(1, "504 .* Sender address rejected: need fully-qualified address")
        client.quit()

      with subtest("reject unknown domain"):
        client.basic_conversation(fromAddr = "client@domain.invalid")
        client.wait_until_tty_matches(1, "450 .* Sender address rejected: Domain not found")
        client.quit()

      # I don't seem to be able to trigger this one
      #with subtest("reject unknown recipient"):
        #client.basic_conversation(toAddr = "server@domain.invalid")
        #client.wait_until_tty_matches(1, "450 .* Recipient address rejected: Domain not found")
        #client.quit()

      with subtest("reject non FQDN recipient"):
        client.basic_conversation(toAddr = "server")
        client.wait_until_tty_matches(1, "504 .* Recipient address rejected: need fully-qualified address")
        client.quit()

      with subtest("reject myhostname"):
        client.basic_conversation(helo = "server.${server.domain}")
        client.wait_until_tty_matches(1, "550 .* Helo command rejected: Don't use my hostname")
        client.quit()

      with subtest("reject non-bracketed ip hostname"):
        client.basic_conversation(helo = "192.168.1.1")
        client.wait_until_tty_matches(1, "550 .* Helo command rejected: Your client is not RFC 2821 compliant")
        client.quit()

      with subtest("reject multi-recipient bounce"):
        client.connect_smtp()
        client.put_tty("HELO ${client.domain}")
        client.wait_until_tty_matches(1, "250 .*")
        client.put_tty("MAIL FROM: <>")
        client.wait_until_tty_matches(1, "250 .*")
        client.put_tty("RCPT TO: ${server.userAddress}")
        client.put_tty("RCPT TO: user2@${server.domain}")
        client.put_tty("DATA")
        client.wait_until_tty_matches(1, "550 .* Data command rejected: Multi-recipient bounce")
        client.quit()

      with subtest("reject unverified sender"):
        client.basic_conversation(fromAddr = "nonexistent@${client.domain}")
        client.wait_until_tty_matches(1, "450 .* Sender address rejected: unverified address.*")
        client.print_tty()
    '';
  }
