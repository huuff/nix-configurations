# My own library for things I want to reuse
{ config, pkgs, lib, ... }:

with lib;

rec {
  fileFromStore = file: pkgs.writeText "${file}" (builtins.readFile file);

  passwd = rec {
    cat = file: "$(cat ${toString file})";
    bcrypt = string: ''$(${pkgs.apacheHttpd}/bin/htpasswd -nbB "" "${string}" | cut -d: -f2)'';
    catAndBcrypt = file: bcrypt (cat file);
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
    http = mkIf ((machineCfg ? ssl) -> !machineCfg.ssl.httpsOnly) (mkDefault 80);
    https = mkIf ((machineCfg ? ssl) && (machineCfg.ssl.enable)) (mkDefault 443);
  };

  mkListen = cfg:
  [
    (mkIf ((cfg ? ssl) -> !cfg.ssl.httpsOnly) {
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

}
