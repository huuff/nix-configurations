# My own library for things I want to reuse
{ config }:
rec {

  passwd = {
    cat = file: "$(cat ${toString file})";

  };

  db = {
    execDDL = ddl: ''${config.services.mysql.package}/bin/mysql -u root -e "${ddl}"'';
    execDML = cfg: dml: ''${config.services.mysql.package}/bin/mysql "${cfg.database.name}" -u "${cfg.database.user}" -p"${passwd.cat cfg.database.passwordFile}" -e "${dml}"'';
  };
}
