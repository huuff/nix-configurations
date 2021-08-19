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
        imports = [
          ../default.nix
        ];

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
          { address = "192.168.2.1"; prefixLength = 24; }
        ];

        services.dnsmasq = {
          enable = true;
          extraConfig = ''
            address=/${domain1}./192.168.2.1
            address=/${domain2}./192.168.2.2
          '';
        };
      };

      machine2 = copyMachine machine1 { 
        networking.interfaces.eth1.ipv4.addresses = [
          { address = "192.168.2.2"; prefixLength = 24; }
        ];

        machines.postfix = {
          canonicalDomain = domain2;
          users = [ user2Address ];
          restrictions.alwaysVerifySender = true;
        };

      };
    };

    testScript = ''
        ${ builtins.readFile ../../../../lib/testing-lib.py }

        machine1.wait_for_unit("postfix.service")
        machine2.wait_for_unit("postfix.service")


        with subtest("machine2 receives email from machine1"):
          machine1.succeed('echo "${testContent}" | mail -s "${testSubject}" -r ${user1Address} ${user2Address}')
          machine2.sleep(5)
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "To: <${user2Address}>")
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "From: System administrator <${user1Address}>")
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "Subject: ${testSubject}")
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "${testContent}")
      '';
  }
