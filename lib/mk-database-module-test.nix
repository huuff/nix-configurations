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
        name = dbWithPassword.name;
        passwordFile = pkgs.writeText "dbpass" dbWithPassword.pass; 
      };
    };

  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet setup-${dbWithPassword.name}-db")

    with subtest("user can connect to database"):
      machine.succeed("mysql -u${dbWithPassword.user} -p${dbWithPassword.pass} ${dbWithPassword.name} -e 'SHOW TABLES;'")
  '';
}
