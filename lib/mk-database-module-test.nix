{ pkgs, ... }:
let
  user = "user";
  pass = "pass";
  name = "test";
in
pkgs.nixosTest {
  name = "mk-database-module";

  machine = { pkgs, ... }: {
    imports = [ (import ./mk-database-module.nix "test") ];

    machines.test.database = {
      enable = true;
      inherit user name;
      passwordFile = pkgs.writeText "dbpass" pass; 
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet setup-test-db")

    with subtest("user can connect to database"):
      machine.succeed("mysql -u${user} -p${pass} ${name} -e 'SHOW TABLES;'")
  '';
}
