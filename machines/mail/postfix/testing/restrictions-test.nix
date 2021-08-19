{ pkgs, ... }:
let
  server = rec {
    domain = "example.com";
    userAddress = "server@${domain}";
  };
  client = rec {
    domain = "test.org";
    userAddress = "client@${domain}";
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
          };

          main = {
            disable_dns_lookups = true;
            smtp_host_lookup = "native";
          };

          users = [ server.userAddress ];
        };

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

          main = {
            disable_dns_lookups = true;
            smtp_host_lookup = "native";
          };
        };

        networking.extraHosts = "192.168.1.2 ${server.domain}";

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

      #with subtest("reject unknown recipient"):
        #client.basic_conversation(toAddr = "server@domain.invalid")
        #client.wait_until_tty_matches(1, "450 .* Recipient address rejected: Domain not found")
        #client.quit()

      with subtest("reject non FQDN recipient"):
        client.basic_conversation(toAddr = "server")
        client.wait_until_tty_matches(1, "504 .* Recipient address rejected: need fully-qualified address")
        client.quit()
    '';
  }
