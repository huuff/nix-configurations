{ pkgs, ... }:
let
  path = "/var/www/osticket";
  adminUsername = "root";
  adminPassword = "adminpass";
in
pkgs.nixosTest {
  name = "osTicket";

  machine = { pkgs, ... }: {
    imports = [ 
      ./default.nix
    ];

    services.osticket = {
      enable = true;

      database.passwordFile = pkgs.writeText "dbpass" "dbpass";
      site.email = "site@test.com";
      installation.path = path;
      
      admin = {
        username = adminUsername;
        passwordFile = pkgs.writeText "adminpass" adminPassword;
        email = "root@test.com";
        firstName = "Firstname";
        lastName = "Lastname";
      };
    };
  };

  testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet deploy-osticket")
        machine.succeed("systemctl is-active --quiet install-osticket")
        machine.succeed("systemctl is-active --quiet setup-users")

      with subtest("admin can login"):
        machine.wait_until_succeeds("pgrep -f 'agetty.*tty1'")
        machine.succeed("useradd -m alice")
        machine.succeed("(echo foobar; echo foobar) | passwd alice")
        machine.wait_until_tty_matches(1, "login: ")
        machine.send_chars("alice\n")
        machine.wait_until_tty_matches(1, "login: alice")
        machine.wait_until_succeeds("pgrep login")
        machine.wait_until_tty_matches(1, "Password: ")
        machine.send_chars("foobar\n")
        machine.wait_until_succeeds("pgrep -u alice bash")

        machine.send_chars("${pkgs.php74}/bin/php ${path}/manage.php agent login\n")
        machine.wait_until_tty_matches(1, "Username: ")
        machine.send_chars("${adminUsername}\n")
        machine.wait_until_tty_matches(1, "Password: ")
        machine.send_chars("${adminPassword}\n")
        machine.wait_until_tty_matches(1, "Successfully authenticated as 'Firstname Lastname', using 'Local Authentication'")

      with subtest("units are inactive on second boot"):
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.fail("systemctl is-active --quiet deploy-osticket")
        machine.fail("systemctl is-active --quiet install-osticket")
        machine.fail("systemctl is-active --quiet setup-users")
    '';
}
