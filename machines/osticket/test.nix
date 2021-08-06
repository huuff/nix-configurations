{ pkgs, ... }:
let
  path = "/var/www/osticket";
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
        username = "root";
        passwordFile = pkgs.writeText "adminpass" "adminpass";
        email = "root@test.com";
        firstName = "Admin";
        lastName = "Admin";
      };
    };
  };

  testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet deploy-osticket")
        machine.succeed("systemctl is-active --quiet install-osticket")
        machine.succeed("systemctl is-active --quiet setup-users")


      with subtest("units are inactive on second boot"):
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.fail("systemctl is-active --quiet deploy-osticket")
        machine.fail("systemctl is-active --quiet install-osticket")
        machine.fail("systemctl is-active --quiet setup-users")
    '';
}
