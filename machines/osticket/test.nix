{ pkgs, ... }:
let
  path = "/var/www/osticket";
  admin = {
    username = "root";
    password = "adminpass";
    firstName = "Firstname";
    lastName = "Lastname";
  };
  user1 = {
    fullName = "Mr. User 1";
    email = "user1@example.com";
  };
  user2 = {
    fullName = "Ms. User 2";
    email = "user2@example.com";
  };
in
  pkgs.nixosTest {
    name = "osTicket";

    machine = { pkgs, ... }: {
      imports = [ 
        ./default.nix
      ];

      environment.systemPackages = [ pkgs.php74 ];

      services.osticket = {
        enable = true;

        database.passwordFile = pkgs.writeText "dbpass" "dbpass";
        site.email = "site@test.com";
        installation.path = path;

        admin = {
          username = admin.username;
          passwordFile = pkgs.writeText "adminpass" admin.password;
          email = "root@test.com";
          firstName = admin.firstName;
          lastName = admin.lastName;
        };


        users = [
          {
            username = "user1";
            fullName = user1.fullName;
            email = user1.email;
            passwordFile = pkgs.writeText "user1pass" "user1pass";
          }
          {
            username = "user2";
            fullName = user2.fullName;
            email = user2.email;
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
        machine.send_chars("php ${path}/manage.php agent login\n")
        machine.wait_until_tty_matches(1, "Username: ")
        machine.send_chars("${admin.username}\n")
        machine.wait_until_tty_matches(1, "Password: ")
        machine.send_chars("${admin.password}\n")
        machine.wait_until_tty_matches(1, "Successfully authenticated as '${admin.firstName} ${admin.lastName}', using 'Local Authentication'")

      with subtest("users are correctly created"):
        machine.succeed("php ${path}/manage.php user list | grep -q '${user1.fullName} <${user1.email}>'")
        machine.succeed("php ${path}/manage.php user list | grep -q '${user2.fullName} <${user2.email}>'")

      with subtest("it's being served correctly"):
        outputContains(machine, 'curl localhost', "<h1>Welcome to the Support Center</h1>")

      with subtest("units are inactive on second boot"):
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.fail("systemctl is-active --quiet deploy-osticket")
        machine.fail("systemctl is-active --quiet install-osticket")
        machine.fail("systemctl is-active --quiet setup-users")
    '';
  }
