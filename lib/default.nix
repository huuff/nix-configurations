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

  db = {
    # XXX: Should I put the password in the command, even though it's in a subshell?
    runSql = cfg: sql: let
      authentication = if (cfg.database.authenticationMethod == "password")
      then ''-p"${passwd.cat cfg.database.passwordFile}"''
      else "";
    in
    ''${config.services.mysql.package}/bin/mysql "${cfg.database.name}" -u "${cfg.database.user}" ${authentication} -e "${sql}"'';

    # The name does't really capture what it does, since it's for running code for database manipulation
    # (create database, etc), that's why it's run by root and no database is specified
    runSqlAsRoot = ddl: ''${config.services.mysql.package}/bin/mysql -u root -e "${ddl}"'';
  };

  # TODO: Make it mkListen since listen isn't even a block...
  mkListenBlock = cfg:
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
