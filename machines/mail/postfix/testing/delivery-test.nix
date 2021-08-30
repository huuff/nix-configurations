{ pkgs, ... }:
let
  domain1 = "example.com";
  clientIP = "172.183.43.2";
  serverIP = "189.122.13.1";
  domain2 = "test.org";
  user1Address = "user1@${domain1}";
  user2Address = "user2@${domain2}";
  testContent = "test content";
  testSubject = "test subject";
  mailPath = "/var/lib/vmail";
  lib = pkgs.lib;
  copyMachine = import ../../../../lib/copy-machine.nix { inherit lib; };
in
  pkgs.nixosTest {
    name = "postfix-correct-delivery";

    nodes = rec {
      client = { pkgs, ... }: {
        imports = [ ../default.nix ];

        environment.systemPackages = with pkgs; [ mailutils ];

        machines.postfix = {
          enable = true;
          canonicalDomain = domain1;

          restrictions = {
            rfcConformant = true;
          };

          inherit mailPath;

          users = [ user1Address ];

        };

        networking.interfaces.eth1.ipv4.addresses = [
          { address = "${clientIP}"; prefixLength = 24; }
        ];

        services.dnsmasq = {
          enable = true;
          extraConfig = ''
            address=/${domain1}./${clientIP}
            address=/${domain2}./${serverIP}
            mx-host=${domain1},client,10
            mx-host=${domain2},server,10
          '';
        };
      };

      server = { pkgs, ... }: { 
        imports = [ ../default.nix ];

        environment.systemPackages = with pkgs; [ mailutils ];

        networking.interfaces.eth1.ipv4.addresses = [
          { address = "${serverIP}"; prefixLength = 24; }
        ];

        machines.postfix = {
          enable = true;
          canonicalDomain = domain2;

          restrictions = {
            rfcConformant = true;
            alwaysVerifySender = true;
          };

          inherit mailPath;

          users = [ user2Address ];

        };

        services.dnsmasq = {
          enable = true;
          extraConfig = ''
            address=/${domain1}./${clientIP}
            address=/${domain2}./${serverIP}
            mx-host=${domain1},client,10
            mx-host=${domain2},server,10
          '';
        };

      };
    };

    testScript = ''
        ${ builtins.readFile ../../../../lib/testing-lib.py }

        def print_user2_mail():
          return "echo p | mail -f ${mailPath}/${user2Address}/"

        client.wait_for_unit("postfix.service")
        server.wait_for_unit("postfix.service")

        with subtest("server receives email from client"):
          client.succeed('echo "${testContent}" | mail -s "${testSubject}" -r ${user1Address} ${user2Address}')
          server.wait_until_succeeds(print_user2_mail())
          server.output_contains(print_user2_mail(), "To: <${user2Address}>")
          server.output_contains(print_user2_mail(), "From: System administrator <${user1Address}>")
          server.output_contains(print_user2_mail(), "Subject: ${testSubject}")
          server.output_contains(print_user2_mail(), "${testContent}")
      '';
  }
