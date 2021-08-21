# My own library for things I want to reuse
{ config, pkgs, ... }:
rec {
  fileFromStore = file: pkgs.writeText "${file}" (builtins.readFile file);

  passwd = rec {
    cat = file: "$(cat ${toString file})";
    bcrypt = string: ''$(${pkgs.apacheHttpd}/bin/htpasswd -nbB "" "${string}" | cut -d: -f2)'';
    catAndBcrypt = file: bcrypt (cat file);
  };

  db = {
    execDDL = ddl: ''${config.services.mysql.package}/bin/mysql -u root -e "${ddl}"'';
    execDML = cfg: dml: let
      authentication = if (cfg.database.authenticationMethod == "password")
      then ''-p"${passwd.cat cfg.database.passwordFile}"''
      else "";
    in
    ''${config.services.mysql.package}/bin/mysql "${cfg.database.name}" -u "${cfg.database.user}" ${authentication} -e "${dml}"'';
  };

  copyMachine = machine: extraConf: { pkgs, config, lib, ... }:
  lib.recursiveUpdate (machine { inherit pkgs config lib; }) extraConf;
}
