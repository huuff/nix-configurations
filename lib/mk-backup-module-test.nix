{ pkgs, ... }:
let
  dbPass = "dbpass";
  backupPath = "/var/lib/backup";
  testName = "backup_test";
  testTable = "TEST_TABLE";
  passphrase = "passphrase";
in
pkgs.nixosTest {
  name = "backup";

  machine = { pkgs, config, ... }: 
  {
    imports = [
      (import ./mk-database-module.nix testName)
      (import ./mk-backup-module.nix testName)
      (import ./mk-installation-module.nix testName)
      (import ./mk-init-module.nix testName)
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

    testScript = ''
        ${ builtins.readFile ./testing-lib.py }

        machine.wait_for_unit("multi-user.target")

        machine.print_output('mysql ${testName} -e "CREATE TABLE ${testTable} (TEST_COLUMN INT);"')
        machine.print_output('mysql ${testName} -e "INSERT INTO ${testTable} VALUES (1), (2), (3);"')

        with subtest("backup is created"):
          machine.systemctl("start backup-${testName}-database")
          [ _, archive ] = machine.execute("BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes BORG_PASSPHRASE=${passphrase} borg list --last 1 --format '{archive}' ${backupPath}")
          print(f"The archive is: {archive}")
          machine.output_contains(command=f"BORG_PASSPHRASE=${passphrase} borg extract --stdout ${backupPath}::{archive}", 
                                  expected="CREATE TABLE `${testTable}`")

        with subtest("database is restored"):
          # First, delete everything in the DB
          machine.succeed('mysql ${testName} -e "DROP DATABASE ${testName};"')
          # Sanity check that the database is removed
          machine.fail("[ -d /var/lib/mysql/${testName} ]")
          # Remove init files to trigger reinitialization
          machine.succeed("rm -rf /etc/inits/${testName}/*")
          # Trigger reinitialization
          machine.systemctl("restart restore-${testName}-backup")
          machine.wait_for_unit("restore-${testName}-backup")
          machine.output_contains(
            command="mysql -sN ${testName} -e 'SELECT * FROM ${testTable};'",
            expected="1\n2\n3")
      '';
}
