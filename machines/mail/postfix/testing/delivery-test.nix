{ pkgs, ... }:
let
  domain1 = "example.com";
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
      machine1 = { pkgs, ... }: {
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

          #master.smtpd.args = [ "-v" ];
        };

        networking.interfaces.eth1.ipv4.addresses = [
          { address = "192.168.2.1"; prefixLength = 24; }
        ];

        services.dnsmasq = {
          enable = true;
          extraConfig = ''
            address=/${domain1}./192.168.2.1
            address=/${domain2}./192.168.2.2
            mx-host=${domain1},machine1,10
            mx-host=${domain2},machine2,10
          '';
        };
      };

      machine2 = { pkgs, ... }: { 
        imports = [ ../default.nix ];

        environment.systemPackages = with pkgs; [ mailutils ];

        networking.interfaces.eth1.ipv4.addresses = [
          { address = "192.168.2.2"; prefixLength = 24; }
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

          #master.smtpd.args = [ "-v" ];
        };

        services.dnsmasq = {
          enable = true;
          extraConfig = ''
            address=/${domain1}./192.168.2.1
            address=/${domain2}./192.168.2.2
            mx-host=${domain1},machine1,10
            mx-host=${domain2},machine2,10
          '';
        };

      };
    };

    testScript = ''
        ${ builtins.readFile ../../../../lib/testing-lib.py }

        def print_user2_mail():
          return "echo p | mail -f ${mailPath}/${user2Address}/"

        machine1.wait_for_unit("postfix.service")
        machine2.wait_for_unit("postfix.service")


        with subtest("machine2 receives email from machine1"):
          machine1.succeed('echo "${testContent}" | mail -s "${testSubject}" -r ${user1Address} ${user2Address}')
          machine2.wait_until_succeeds(print_user2_mail())
          machine2.output_contains(print_user2_mail(), "To: <${user2Address}>")
          machine2.output_contains(print_user2_mail(), "From: System administrator <${user1Address}>")
          machine2.output_contains(print_user2_mail(), "Subject: ${testSubject}")
          machine2.output_contains(print_user2_mail(), "${testContent}")
      '';
  }
