{ pkgs, ... }:
let
  forBob = {
    subject = "BobTest";
    content = "Mail for bob";
  };
  forAlice = {
    subject = "AliceTest";
    content = "Mail for alice";
  };
in
pkgs.nixosTest {
  name = "postfix";

  machine = { pkgs, ... }: {
    imports = [
      ./default.nix
    ];

    environment.systemPackages = with pkgs; [ mailutils ];

    machines.postfix = {
      enable = true;
      restrictions = "rfc_conformant";
    };

    users.users = {
      alice = {
        password = "password";
        isNormalUser = true;
      };
      bob = {
        password = "password";
        isNormalUser = true;
      };
    };
  };

  testScript = ''
    ${ builtins.readFile ../../../lib/testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("units are active"):
      machine.succeed("systemctl is-active --quiet postfix")

    with subtest("mails are delivered"):
      # Send mail from alice to bob
      machine.switch_tty(1)
      machine.login(tty=1, user="alice")
      machine.send_chars("echo '${forBob.content}' | mail -s '${forBob.subject}' bob@localhost\n")
      # Send mail from bob to alice
      machine.switch_tty(2)
      machine.login(tty=2, user="bob")
      machine.send_chars("echo '${forAlice.content}' | mail -s '${forAlice.subject}' alice@localhost\n")
      # Read mail for alice
      machine.switch_tty(1)
      machine.send_chars("echo p | mail\n")
      machine.sleep(1)
      output = machine.get_tty_text(1)
      contains(output, "Subject: ${forAlice.subject} ")
      contains(output, "From: bob")
      contains(output, "${forAlice.content}")
      # Read mail for bob
      machine.switch_tty(2)
      machine.send_chars("echo p | mail\n")
      machine.sleep(1)
      output = machine.get_tty_text(2)
      contains(output, "Subject: ${forBob.subject}")
      contains(output, "${forBob.content}")
  '';
}
