{ pkgs, ... }:
let
  dbPass = "dbpass";
  backupPath = "/var/lib/backup";
  user = "test";
  testTable = "TEST_TABLE";
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
      (import ./mk-init-module.nix "test")
    ];


    environment.systemPackages = with pkgs; [ mysql borgbackup ];

    machines.test = {
      installation.user = user;

      backup = {
        database = {
          enable = true;
          repository = {
            path = backupPath;
          };
        };
      };
    };
  };

    testScript = ''
        ${ builtins.readFile ./testing-lib.py }

        machine.wait_for_unit("multi-user.target")

        machine.print_output('sudo -u${user} mysql test -e "CREATE TABLE ${testTable} (TEST_COLUMN INT);"')
        machine.print_output('sudo -u${user} mysql test -e "INSERT INTO ${testTable} VALUES (1), (2), (3);"')

        with subtest("backup is created"):
          machine.systemctl("start backup-test-database")
          [ _, archive ] = machine.execute("BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes borg list --last 1 --format '{archive}' ${backupPath}")
          print(f"The archive is: {archive}")
          machine.output_contains(command=f"borg extract --stdout ${backupPath}::{archive}", 
                                  expected="CREATE TABLE `${testTable}`")
      '';
}
