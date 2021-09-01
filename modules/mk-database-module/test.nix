{ pkgs, testingLib, ... }:
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
        (import ./default.nix dbWithPassword.name)
        (import ./default.nix dbWithSocket.name)
      ];

      services.mysql.package = lib.mkForce pkgs.mariadb;

      users.users.${dbWithSocket.user}.isNormalUser = true;

      machines = {
        ${dbWithPassword.name}.database = {
          user = dbWithPassword.user;
          authenticationMethod = "password";
          passwordFile = pkgs.writeText "dbpass" dbWithPassword.pass; 
        };

        ${dbWithSocket.name}.database = {
          authenticationMethod = "socket";
          user = dbWithSocket.user;
        };
      };
    };

    testScript = ''
      ${ testingLib }

      machine.wait_for_unit("multi-user.target")

      with subtest("unit is active"):
        machine.succeed("systemctl is-active --quiet setup-${dbWithPassword.name}-db")

      with subtest("user can connect to database with password"):
        machine.succeed("mysql -u${dbWithPassword.user} -p${dbWithPassword.pass} ${dbWithPassword.name} -e 'quit'")

      with subtest("user can connect to satabase with socket"):
        machine.succeed("sudo -u ${dbWithSocket.user} mysql ${dbWithSocket.name} -e 'quit'")
    '';
  }
