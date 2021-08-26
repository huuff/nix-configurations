{ pkgs, ... }:
let
  # Database TODO: Put it in an attr set and improve it generally
  dbPass = "dbpass";
  backupPath = "/var/lib/backup";
  testName = "backup_test";
  testTable = "TEST_TABLE";
  passphrase = "passphrase";
in
pkgs.nixosTest {
  name = "database-backup";

  nodes = {
    machine = { pkgs, config, ... }: {
      imports = [
        (import ../../lib/mk-database-module.nix testName)
        (import ./default.nix testName)
        (import ../../lib/mk-installation-module.nix testName)
        (import ../../lib/mk-init-module.nix testName)
      ];


      environment.systemPackages = with pkgs; [ mysql borgbackup ];

      machines.${testName} = {
        installation.user = testName;

        backup = {
          restore = true;

          database = {
            enable = true;
            repository = {
              path = backupPath;
              encryption = {
                mode = "repokey";
                passphraseFile = pkgs.writeText passphrase passphrase;
              };
            };
          };
        };
      };
    };
  };

    testScript = ''
        ${ builtins.readFile ../../lib/testing-lib.py }

        def borg_boilerplate():
          return "BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes BORG_PASSPHRASE=${passphrase}"

        # DATABASE BACKUP TESTS
        machine.wait_for_unit("multi-user.target")

        machine.succeed('mysql ${testName} -e "CREATE TABLE ${testTable} (TEST_COLUMN INT);"')
        machine.succeed('mysql ${testName} -e "INSERT INTO ${testTable} VALUES (1), (2), (3);"')

        with subtest("database backup is created"):
          machine.systemctl("start backup-${testName}-database")
          [ _, archive ] = machine.execute(f"{borg_boilerplate()} borg list --last 1 --format '{{archive}}' ${backupPath}")
          print(f"The archive is: {archive}")
          machine.output_contains(command=f"{borg_boilerplate()} borg extract --stdout ${backupPath}::{archive}", expected="CREATE TABLE `${testTable}`")

        with subtest("database is restored"):
          # First, delete everything in the DB
          machine.succeed('mysql ${testName} -e "DROP DATABASE ${testName};"')
          # Sanity check that the database is removed
          machine.fail("[ -d /var/lib/mysql/${testName} ]")
          # Remove init files to trigger reinitialization
          machine.succeed("rm -rf /etc/inits/${testName}/*")
          # Trigger reinitialization
          machine.systemctl("restart restore-${testName}-database-backup")
          machine.wait_for_unit("restore-${testName}-database-backup")
          machine.output_contains(
            command="mysql -sN ${testName} -e 'SELECT * FROM ${testTable};'",
            expected="1\n2\n3")
      '';
}
