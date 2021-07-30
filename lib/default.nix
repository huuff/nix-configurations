# My own library for things I want to reuse
{ config }:
rec {
  catPasswordFile = file: "$(cat ${toString file})";

  db = {
    execDDL = ddl: ''${config.services.mysql.package}/bin/mysql -u root -e "${ddl}"'';
    execDML = cfg: dml: ''${config.services.mysql.package}/bin/mysql "${cfg.database.name}" -u "${cfg.database.user}" -p"${catPasswordFile cfg.database.passwordFile}" -e "${dml}"'';
  };
}
