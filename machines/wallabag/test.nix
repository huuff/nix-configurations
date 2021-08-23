{ pkgs, ... }:
let
  user1 = {
    name = "user1";
    pass = "user1pass";
    email = "user1@example.com";
  };
  user2 = {
    name = "user2";
    pass = "user2pass";
    email = "user2@example.com";
  };
  databasePassword = "dbpass";
  path = "/var/lib/wallabag";
  user = "wallabag";
in
  pkgs.nixosTest {
    name = "wallabag";

    machine = { pkgs, ... }: {
      imports = [ ./default.nix ];

      environment.systemPackages = [ pkgs.php74 ];

      machines.wallabag = {
        enable = true;
        ssl.enable = false;

        installation = { inherit path user; };

        users = [
          {
            username = user1.name;
            passwordFile = pkgs.writeText "user1pass" user1.pass;
            email = user1.email;
          }
          {
            username = user2.name;
            passwordFile = pkgs.writeText "user1pass" user2.pass;
            email = user2.email;
            superAdmin = true;
          }
        ];
      };
    };

    testScript = ''
      ${ builtins.readFile ../../lib/testing-lib.py }

      def listUsers():
        return "cd ${path} && sudo -u ${user} php bin/console wallabag:user:list | tr -s ' '"

      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet copy-wallabag")
        machine.succeed("systemctl is-active --quiet create-parameters")
        machine.succeed("systemctl is-active --quiet install-wallabag")
        machine.succeed("systemctl is-active --quiet setup-users")

      with subtest("nginx is serving wallabag"):
        machine.output_contains(command='curl http://localhost/login',
                                expected='<title>Welcome to wallabag! – wallabag</title>')

      with subtest("default user is deactivated"):
        machine.output_contains(listUsers(), "wallabag wallabag@wallabag.io no yes")

      with subtest("users were created correctly"):
        machine.output_contains(listUsers(), "user1 user1@example.com yes no")
        machine.output_contains(listUsers(), "user2 user2@example.com yes yes")
    '';
  }
