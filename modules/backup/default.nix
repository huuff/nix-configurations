# TODO: Maybe passphrase from file descriptor? This might allow less eavesdropping
name:
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.machines.${name}.backup;

  myLib = import ../../lib/default.nix { inherit config pkgs lib; };
  borgLib = import ./borg-lib.nix { inherit lib myLib; };

  remote = with types; submodule {
    options = {
      user = mkOption {
        type = str;
        default = null;
        description = "User that will be used to connect through SSH to the repository";
      };

      hostname = mkOption {
        type = str;
        default = null;
        description = "Hostname where backups will be sent";
      };

      key = mkOption {
        type = oneOf [ path str ];
        default = null;
        description = "Path of the key used to connect through ssh to the repository";
      };

      path = mkOption {
        type = str;
        default = null;
        description = "Path where the archive will be created";
      };
    };
  };


  repository = with types; submodule {
    options = { 
      localPath = mkOption {
        type = nullOr (oneOf [ str path ]);
        default = "/var/lib/backup/${name}";
        description = "Path where the backup will be stored, if remote, do not use the 'ssh://' format, but fill in the remote option";
      };

      remote = mkOption {
        type = nullOr remote;
        default = null;
        description = "SSH options for a remote repository";
      };

      encryption = {
        mode = mkOption {
          type = enum [ "none" "authenticated" "repokey" "keyfile" ];
          default = "none";
          description = "Encryption mode to use";
        };

        passphraseFile = mkOption {
          type = nullOr (oneOf [ str path ]);
          default = null;
          description = "Encryption key passphrase";
        };
      };
    };
  };
in
  {

    imports = [
      (import ./database.nix { inherit name repository borgLib; })
      (import ./directories.nix { inherit name repository borgLib; })
    ];

    options = with types; {
      machines.${name}.backup = {
        user = mkOption {
          type = str;
          default = config.machines.${name}.installation.user or null;
          description = "User that will run the backup script";
        };

        restore = mkOption {
          type = bool;
          default = false;
          description = ''
            Automatically restore the latest backup after initialization.
            This is a destructive operation since all previous files/databaes will be replaced by the contents of the backup.
            '';
        };

        frequency = mkOption {
          type = enum [ "minutely" "hourly" "daily" "monthly" "weekly" "yearly" "quarterly" "semianually" ];
          default = "daily";
          description = "Frequency with which the data will be backed up";
        };

        # TODO: Maybe add auto? although I struggle to find how to support it
        compression = {
          algorithm = mkOption {
            type = enum [ "none" "lz4" "zstd" "zlib" "lzma" ];
            default = "lz4";
            description = "Compression algorithm to use";
          };

          level = mkOption {
            type = nullOr (ints.between 1 (if cfg.compression.algorithm == "zstd" then 22 else 9));
            default = 
            if cfg.compression.algorithm == "zstd" then 3
            else if (cfg.compression.algorithm == "lzma" || cfg.compression.algorithm == "zlib") then 6
            else null; # lz4 and none
            description = "Level of compression to apply";
          };
        };
      };
    };

    config = {
      assertions = [
        {
          assertion = ((cfg.database.repository.localPath != null) -> cfg.database.repository.remote == null) && ((cfg.directories.repository.localPath != null) -> cfg.directories.repository.remote == null);
          message = "You can't set a path and a remote at the same time for a repository!";
        }
        {
          assertion = config.machines.${name} ? initialization;
          message = "You have imported the backup module for ${name}, but not the initialization module! Note that the backup module requires it.";
        }
        {
          assertion = (cfg.compression.algorithm == "none" || cfg.compression.algorithm == "lz4") -> (cfg.compression.level == null);
          message = "You specified a compression level for ${name} while setting the compression to `none` or `lz4`. This is not supported";
        }
      ];

      machines.${name}.initialization.units = (mkBefore [
        (mkIf (cfg.database.enable || cfg.directories.enable) {
          name = "initialize-${name}-repositories";
          description = "Initialize the ${name} borg repository if not already a repository";
          path = with pkgs; [ borgbackup openssh ];
          script = let
            initRepoIfNotInitialized = repo: ''
              ${borgLib.setEnv repo}
              set +e
              borg info ${borgLib.buildPath repo}
              if [ $? -eq 2 ]; then
                borg init -e${repo.encryption.mode} ${borgLib.buildPath repo}
              fi
              '';
          in ''
              ${optionalString cfg.database.enable (initRepoIfNotInitialized cfg.database.repository)}
              ${optionalString cfg.directories.enable (initRepoIfNotInitialized cfg.directories.repository)}
          '';
          idempotent = true;
        })
      ]);
    };
  }
