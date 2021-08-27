{ pkgs, ... }:
let
  testName = "backup_test";
  user = "test";
  dir1 = "/var/test/backup1";
  dir1Contents = "test1";
  dir2Contents = "test2";
  dir2 = "/var/test/backup2";
  remotePath = "/var/backups";
  clientKeyDir = "/etc/ssh/key";
  clientKeyPath = "${clientKeyDir}/test_rsa";
  sshPub = ./test_rsa.pub;
  sshPriv = ./test_rsa;
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
        "d ${dir1} 755 ${user} ${user} - -"
        "d ${dir2} 755 ${user} ${user} - -"
        "d ${clientKeyDir} 755 ${user} ${user} - -"
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
                key = clientKeyPath;
                path = remotePath;
              };
            };
          };
        };
      };

      systemd.services.copy-ssh-key = {
        description = "Copy ssh key from store and give permissions appropriate for using it";

        wantedBy = [ "multi-user.target" ];

        script = ''
          cp -v ${sshPriv} ${clientKeyPath}
          chown ${user}:${user} ${clientKeyPath}
          chmod 0600 ${clientKeyPath}
        '';

        serviceConfig = {
          type = "oneshot";
        };
      };
    };

    server = { pkgs, ... }: {

      environment.systemPackages = with pkgs; [ borgbackup ];
      
      # TODO: Make this a machine. Is it useful for something?
      #systemd.services.borg-serve = {
        #description = "Serve borg";

        #script = "borg serve";

        #path = with pkgs; [ borgbackup ];

        #wantedBy = [ "multi-user.target" ];

        #unitConfig = {
          #After = [ "network-online.target" ];
          #Requires = [ "network-online.target" ];
        #};

        #serviceConfig = {
          #User = "root";
          #Restart = "always";
        #};
      #};

      systemd.tmpfiles.rules = [ 
        "d ${remotePath} 755 root root - -"
      ];

      services.openssh = {
        enable = true;
        permitRootLogin = "yes";
      };

      # There must be some way to put a file instead of a string
      #users.users.root.openssh.authorizedKeys.keys = [ (builtins.readFile sshPriv) ];

      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwLhq5YArTuVIdGfXXj/UsR1G3lnKJ7ctoLivWs0gZWswszj09rBSjJVmR8MtWwsenxNuVa0cXKZ3OtXZT3E5WzuzquDyn9JlfzpjrsL9OkFQ3H9IeEFTWzPQgyL7EnUskNfHlIEIHGNIVfWLq0O3VCzG58Z0LHfxtSdxFOLW7UEXRJJ/Ui1mnmHcJ7MTaplTCZlGBNyKkv0CJNGUNjty3OCbe7TsoNuPDaWIC4+D8MdjfyBBwYPaeo9aotGrD+9Wk2iKLCSO6VgTiQSR9FDhJBtP9NReKli0vJSFq4NNRnUgbYbyX9VZHfX3XlBEFaR7+Wldh4EgNdrPPq8EftqYv haf@desktop"
      ];

    };
  };

  # TODO: test that we can restore the contents
  testScript = ''
        ${ builtins.readFile ../../lib/testing-lib.py }

        def borg_boilerplate():
          return "BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes"

        server.wait_for_unit("multi-user.target")
        client.wait_for_unit("multi-user.target")

        with subtest("backup is created"):
          # Add random files to the directories so they have something to backup
          client.succeed("touch ${dir1}/file1")
          client.succeed("touch ${dir2}/file2")
          client.succeed("echo ${dir1Contents} > ${dir1}/file1")
          client.succeed("echo ${dir2Contents} > ${dir2}/file2")
          # Do the backup
          client.systemctl("start backup-${testName}-directories")
          # See if the contents are there
          [ _, last_archive ] = server.execute(f"{borg_boilerplate()} borg list --last 1 --format '{{archive}}' ${remotePath}")
          server.output_contains(f"{borg_boilerplate()} borg extract --stdout ${remotePath}::{last_archive}", "${dir1Contents}")
          server.output_contains(f"{borg_boilerplate()} borg extract --stdout ${remotePath}::{last_archive}", "${dir2Contents}")
      '';
}
