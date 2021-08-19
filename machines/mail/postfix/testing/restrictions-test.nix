{ pkgs, ... }:
# TODO: Some names as in options so I can use inherit??
let
  domain = "example.com";
  userAddress = "user@${domain}";
in
pkgs.nixosTest {
  name = "postfix-restrictions";

  machine = { pkgs, ... }: {
    imports = [
      ../default.nix
    ];


    environment.systemPackages = with pkgs; [ telnet ];

    machines.postfix = {
      enable = true;
      canonicalDomain = domain;

      restrictions = {
        noOpenRelay = true;
        rfcConformant = true;
        antiForgery = true;
      };

      users = [ userAddress ];
    };

  };

  testScript = ''
    ${ builtins.readFile ../../../../lib/testing-lib.py }

    machine.wait_for_unit("postfix.service")
    machine.create_user_and_login()

    with subtest("helo required"):
      machine.send_chars("telnet localhost 25\n")
      machine.sleep(0.5)
      machine.print_tty(1)
      machine.wait_until_tty_matches(1, "220 .*?.${domain} ESMTP Postfix")
      machine.send_chars("MAIL FROM: <sender@example.com>\n")
      machine.sleep(1)
      machine.print_tty(1)
      machine.wait_until_tty_matches(1, "503 .*? send HELO/EHLO first")
      machine.send_chars("QUIT\n")

  '';
}
