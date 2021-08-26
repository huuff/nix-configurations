{ pkgs, ... }:
let
  testName = "backup_test";
  user = "test";
  dir1 = "/var/test/backup";
  dir2 = "/var/test/backup2";
  remotePath = "/var/backups";
  serverIP = "192.168.2.1";
  sshPub = pkgs.writeText "ssh-public-key" ./test_rsa.pub;
  sshPriv = pkgs.writeText "ssh-private-key" ./test_rsa;
in
pkgs.nixosTest {
  name = "directories-backup";

  nodes = {
    client = { pkgs, config, ... }: {
      imports = [
        (import ./default.nix testName)
        (import ../../lib/mk-installation-module.nix testName)
        (import ../../lib/mk-init-module.nix testName)
      ];

      environment.systemPackages = with pkgs; [ borgbackup ];

      systemd.tmpfiles.rules = [
        "d ${dir1} 755 ${testName} ${testName} - - "
        "d ${dir2} 755 ${testName} ${testName} - - "
      ];

      machines.${testName} = {
        installation.user = user;

        backup = {
          restore = true;

          directories = {
            enable = true;
            paths = [ dir1 dir2 ];

            repository = {
              encryption.mode = "none";
              # TODO: Give some form of providing a default but just in the case that
              # no remote is specified
              path = null;

              remote = {
                user = "root";
                hostname = "server";
                key = sshPriv;
                path = remotePath;
              };
            };
          };
        };
      };
    };

    server = { pkgs, ... }: {
      
      environment.systemPackages = with pkgs; [ borgbackup ];

      # TODO: Make this a machine
      systemd.services.borg-serve = {
        description = "Serve borg";

        script = "borg serve";

        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "forking";
          User = "root";
          Restart = "always";
        };
      };

      systemd.tmpfiles.rules = [ 
        "d ${remotePath} 755 root root - -"
      ];

      services.openssh = {
        enable = true;
        permitRootLogin = "yes";
      };

      # There must be some way to put a file instead of a string
      users.users.root.openssh.authorizedKeys.keys = [ (builtins.readFile sshPriv) ];
    };
  };

    testScript = ''
        ${ builtins.readFile ../../lib/testing-lib.py }

        client.wait_for_unit("multi-user.target")
        server.wait_for_unit("multi-user.target")

        with subtest("backup is created"):
          # Add random files to the directories so they have something to backup
          client.succeed("echo test1 > ${dir1}/file1")
          client.succeed("echo test2 > ${dir2}/file2")
          client.systemctl("start backup-${testName}-directories")
      '';
}
