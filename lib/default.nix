# My own library for things I want to reuse
{ config, pkgs, lib, ... }:

with lib;

rec {
  passwd = rec {
    cat = file: "$(cat ${toString file})";

    bcrypt = string: ''$(${pkgs.apacheHttpd}/bin/htpasswd -nbB "" "${string}" | cut -d: -f2)'';

    catAndBcrypt = file: bcrypt (cat file);

    mkOption = with types; lib.mkOption {
      type = oneOf [ str path ];
      default = null;
      description = "Path to the file containing the password";
    };

    mkNullableOption = with types; lib.mkOption {
      type = nullOr (oneOf [ str path ]);
      default = null;
      description = "Path to the file containing the password";
    };
  };

  db = rec {
    sqlHeredoc = sql: ''<<END_OF_SQL
      ${sql}
END_OF_SQL'';

    # XXX: Should I put the password in the command, even though it's in a subshell?
    runSql = cfg: sql: ''${config.services.mysql.package}/bin/mysql "${cfg.name}" ${authentication cfg} ${sqlHeredoc sql}'';

    # The name does't really capture what it does, since it's for running code for database manipulation
    # (create database, etc), that's why it's run by root and no database is specified
    runSqlAsRoot = ddl: ''${config.services.mysql.package}/bin/mysql -u root ${sqlHeredoc ddl}'';

    # Using `toString` so if it's a file path, it doesn't get into the nix store
    authentication = dbCfg: ''-u ${dbCfg.user} ${optionalString (dbCfg.authenticationMethod == "password") "-p\"${passwd.cat (toString dbCfg.passwordFile)}\""}'';

  };

  mkDefaultHttpPorts = machineCfg: {
    http = mkIf ((machineCfg ? ssl) -> !machineCfg.ssl.sslOnly) (mkDefault 80);
    https = mkIf ((machineCfg ? ssl) && (machineCfg.ssl.enable)) (mkDefault 443);
  };

  mkListen = cfg:
  [
    (mkIf ((cfg ? ssl) -> !cfg.ssl.sslOnly) {
      addr = "0.0.0.0";
      port = cfg.installation.ports.http;
      ssl = false;
    })

    (mkIf ((cfg ? ssl) && cfg.ssl.enable) {
      addr = "0.0.0.0";
      port = cfg.installation.ports.https;
      ssl = true;
    })
  ];

  # Copy-pasted from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/gitea.nix
  mkHardenedUnit = paths: unit: recursiveUpdate {
    serviceConfig = {
     # Access write directories
      ReadWritePaths = paths;
      UMask = "0027";
      # Capabilities
      CapabilityBoundingSet = "";
      # Security
      NoNewPrivileges = true;
      # Sandboxing
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = true;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX AF_INET AF_INET6" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      PrivateMounts = true;
      # System Call Filtering
      SystemCallArchitectures = "native";
      SystemCallFilter = "~@clock @cpu-emulation @debug @keyring @memlock @module @mount @obsolete @raw-io @reboot @resources @setuid @swap";
    };
  } unit;

}
