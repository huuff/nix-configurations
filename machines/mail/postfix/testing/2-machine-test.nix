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
    name = "postfix-2-machines";

    nodes = rec {
      machine1 = { pkgs, ... }: {
        imports = [
          ../default.nix
        ];

        environment.systemPackages = with pkgs; [ mailutils ];

        machines.postfix = {
          enable = true;
          canonicalDomain = domain1;

          restrictions.rfcConformant = false;

          inherit mailPath;

          users = [ user1Address ];

          main = {
            disable_dns_lookups = true;
            smtp_host_lookup = "native";
          };
        };

        networking = {
          extraHosts = "192.168.1.2 ${domain2}";
        };
      };

      machine2 = copyMachine machine1 { 
        machines.postfix = {
          canonicalDomain = domain2;
          users = [ user2Address ];
        };

        networking.extraHosts = "192.168.1.1 ${domain1}" ;
      };
    };

    testScript = ''
        ${ builtins.readFile ../../../../lib/testing-lib.py }

        machine1.wait_for_unit("postfix.service")
        machine2.wait_for_unit("postfix.service")


        with subtest("machine2 receives email from machine1"):
          machine1.succeed('echo "${testContent}" | mail -s "${testSubject}" -r ${user1Address} ${user2Address}')
          machine2.sleep(1)
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "To: <${user2Address}>")
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "From: System administrator <${user1Address}>")
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "Subject: ${testSubject}")
          machine2.output_contains("echo p | mail -f ${mailPath}/${user2Address}/", "${testContent}")
      '';
  }
