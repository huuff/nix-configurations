{ pkgs, ... }:
let
  dbPass = "dbpass";
  backupPath = "/var/backup/test/db";
in
pkgs.nixosTest {
  name = "backup";

  machine = { pkgs, config, ... }: 
  let
    myLib = import ./default.nix { inherit pkgs config; };
  in
  {
    imports = [
      (import ./mk-database-module.nix "test")
      (import ./mk-backup-module.nix "test")
      (import ./mk-installation-module.nix "test")
    ];

    environment.systemPackages = with pkgs; [ mysql ];

    machines.test = {
      database = {
        enable = true;
        passwordFile = pkgs.writeText dbPass dbPass;
      };

      backup = {
        database = {
          enable = true;
          path = backupPath;
        };
      };
    };
  };

    testScript = ''
        ${ builtins.readFile ./testing-lib.py }

        machine.wait_for_unit("multi-user.target")

        machine.print_output('mysql -u test -p${dbPass} test -e "CREATE TABLE TEST_TABLE (TEST_COLUMN INT);"')
        machine.print_output('mysql -u test -p${dbPass} test -e "INSERT INTO TEST_TABLE VALUES (1), (2), (3);"')

        machine.sleep(1)
        machine.print_output('mysql -u test -p${dbPass} test -e "SELECT * FROM TEST_TABLE;"')

        with subtest("backup is created"):
          machine.systemctl("start backup-test-database")
          machine.sleep(2)
          machine.print_output("cat ${backupPath}/*.sql")
      '';
}
