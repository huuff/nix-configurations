{ pkgs, ... }:
let
  dbWithPassword = {
    user = "user1";
    pass = "pass";
    name = "passwd";
  };
  dbWithSocket = {
    user = "user2";
    name = "socket";
  };
in
  pkgs.nixosTest {
    name = "mk-database-module";

    machine = { pkgs, lib, ... }: {
      imports = [ 
        (import ./mk-database-module.nix dbWithPassword.name)
        (import ./mk-database-module.nix dbWithSocket.name)
      ];

      services.mysql.package = lib.mkForce pkgs.mariadb;

      machines = {
        ${dbWithPassword.name}.database = {
          user = dbWithPassword.user;
          passwordFile = pkgs.writeText "dbpass" dbWithPassword.pass; 
        };

        ${dbWithSocket.name}.database = {
          user = dbWithSocket.user;
        };
      };
      users.users.${dbWithSocket.user} = {
        isNormalUser = true;
        password = "password";
      };
    };

    testScript = ''
      ${ builtins.readFile ./testing-lib.py }

      machine.wait_for_unit("multi-user.target")

      with subtest("unit is active"):
        machine.succeed("systemctl is-active --quiet setup-${dbWithPassword.name}-db")

      with subtest("user can connect to database with password"):
        machine.succeed("mysql -u${dbWithPassword.user} -p${dbWithPassword.pass} ${dbWithPassword.name} -e 'quit'")

      with subtest("user can connect to satabase with socket"):
        machine.login("${dbWithSocket.user}")
        machine.succeed_tty("mysql ${dbWithSocket.name} -e 'quit'")
    '';
  }
