# My own library for things I want to reuse
{ config, pkgs, ... }:
rec {

  # Just a function I use for testing in nixos-shell
  fileFromStore = file: pkgs.writeText "${file}" (builtins.readFile file);

  passwd = rec {
    cat = file: "$(cat ${toString file})";
    bcrypt = string: ''$(${pkgs.apacheHttpd}/bin/htpasswd -nbB "" "${string}" | cut -d: -f2)'';
    catAndBcrypt = file: bcrypt (cat file);
  };


  db = {
    execDDL = ddl: ''${config.services.mysql.package}/bin/mysql -u root -e "${ddl}"'';
    execDML = cfg: dml: ''${config.services.mysql.package}/bin/mysql "${cfg.database.name}" -u "${cfg.database.user}" -p"${passwd.cat cfg.database.passwordFile}" -e "${dml}"'';
  };
}
