{ pkgs, ... }:
let
  path = "/var/www/osticket";
  adminUsername = "root";
  adminPassword = "adminpass";
  adminFirstName = "Firstname";
  adminLastName = "Lastname";
  user1FullName = "Mr. User 1";
  user1Email = "user1@example.com";
  user2FullName = "Ms. User 2";
  user2Email = "user2@example.com";
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
          firstName = adminFirstName;
          lastName = adminLastName;
        };


        users = [
          {
            username = "user1";
            fullName = user1FullName;
            email = user1Email;
            passwordFile = pkgs.writeText "user1pass" "user1pass";
          }
          {
            username = "user2";
            fullName = user2FullName;
            email = user2Email;
            passwordFile = pkgs.writeText "user2pass" "user2pass";
          }
        ];
      };
    };

    testScript = ''
      ${ builtins.readFile ../../lib/testing-lib.py }

      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet deploy-osticket")
        machine.succeed("systemctl is-active --quiet install-osticket")
        machine.succeed("systemctl is-active --quiet setup-users")

      login(machine)

      with subtest("admin can login"):
        machine.send_chars("${pkgs.php74}/bin/php ${path}/manage.php agent login\n")
        machine.wait_until_tty_matches(1, "Username: ")
        machine.send_chars("${adminUsername}\n")
        machine.wait_until_tty_matches(1, "Password: ")
        machine.send_chars("${adminPassword}\n")
        machine.wait_until_tty_matches(1, "Successfully authenticated as '${adminFirstName} ${adminLastName}', using 'Local Authentication'")

      with subtest("users are correctly created"):
        machine.succeed("${pkgs.php74}/bin/php ${path}/manage.php user list | grep -q '${user1FullName} <${user1Email}>'")
        machine.succeed("${pkgs.php74}/bin/php ${path}/manage.php user list | grep -q '${user2FullName} <${user2Email}>'")

      with subtest("units are inactive on second boot"):
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.fail("systemctl is-active --quiet deploy-osticket")
        machine.fail("systemctl is-active --quiet install-osticket")
        machine.fail("systemctl is-active --quiet setup-users")
    '';
  }
