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

    with subtest("requires HELO"):
      machine.put_tty("telnet localhost 25")
      machine.wait_until_tty_matches(1, "220 .*?.${domain} ESMTP Postfix")
      machine.put_tty("MAIL FROM: <sender@example.com>")
      machine.wait_until_tty_matches(1, "503 .*? send HELO/EHLO first")
      machine.put_tty("QUIT")
  '';
}
