{ pkgs, ... }:
let
  directory = "/home/neuron";
in
pkgs.nixosTest {
  name = "osTicket";

  machine = { pkgs, ... }: {
    imports = [ 
      ./default.nix
    ];

    environment.systemPackages = with pkgs; [ git ];

    nix.useSandbox = false;
    
    services.osticket = {
      enable = true;

      database.passwordFile = pkgs.writeText "dbpass" "dbpass";
      site.email = "site@test.com";
      
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
      machine.wait_for_unit("default.target")

      with subtest("units activate only on first boot"):
        machine.succeed("systemctl is-active --quiet deploy-osticket")
        machine.succeed("systemctl is-active --quiet install-osticket")
        machine.succeed("systemctl is-active --quiet setup-users")

        machine.shutdown()
        machine.start()

        machine.wait_for_unit("default.target")
        machine.fail("systemctl is-active --quiet deploy-osticket")
        machine.fail("systemctl is-active --quiet install-osticket")
        machine.fail("systemctl is-active --quiet setup-users")
    '';
}
