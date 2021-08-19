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

          users = [ server.userAddress ];
        };

        networking.firewall.allowedTCPPorts = [ 25 ];
      };

      client = { pkgs, ... }: {
        imports = [ ../default.nix ];

        environment.systemPackages = with pkgs; [ telnet ];

        machines.postfix = {
          enable = true;
          canonicalDomain = client.domain;

          users = [ client.userAddress ];
        };

      };
  };

    testScript = ''
      ${ builtins.readFile ../../../../lib/testing-lib.py }

      def connect_smtp(self):
        client.put_tty("telnet server 25")
        client.wait_until_tty_matches(1, "220 .*?.${server.domain} ESMTP Postfix")

      Machine.connect_smtp = connect_smtp
      del(connect_smtp)

      client.wait_for_unit("postfix.service")
      server.wait_for_unit("postfix.service")
      client.create_user_and_login()

      with subtest("requires HELO"):
        client.connect_smtp()
        client.put_tty("MAIL FROM: <sender@example.com>")
        client.wait_until_tty_matches(1, "503 .*? send HELO/EHLO first")
        client.put_tty("QUIT")

      with subtest("requires FQDN"):
        client.connect_smtp()
        client.put_tty("HELO client")
        client.wait_until_tty_matches(1, "250 .*")
        client.put_tty("MAIL FROM: <sender@example.com>")
        client.wait_until_tty_matches(1, "250 .*")
        client.put_tty("RCPT TO: ${server.userAddress}")
        client.wait_until_tty_matches(1, "504 .* need fully-qualified hostname")
        client.put_tty("QUIT")

    '';
  }
