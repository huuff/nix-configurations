# My own library for things I want to reuse
{ lib, config }:
rec {
  catPasswordFile = file: "$(cat ${toString file})";

  db = rec {
    execDDL = ddl: ''${config.services.mysql.package}/bin/mysql -u root -e "${ddl}"'';
    execDML = cfg: dml: ''${config.services.mysql.package}/bin/mysql "${cfg.database.name}" -u "${cfg.database.user}" -p"${catPasswordFile cfg.database.passwordFile}" -e "${dml}"'';

    setupUnit = cfg:
    {
      description = "Create ${cfg.database.name} and give ${cfg.database.user} permissions to it";

      script = execDDL ''
          CREATE DATABASE ${cfg.database.name};
          CREATE USER '${cfg.database.user}'@${cfg.database.host} IDENTIFIED BY '${catPasswordFile cfg.database.passwordFile}';
          GRANT ALL PRIVILEGES ON ${cfg.database.name}.* TO '${cfg.database.user}'@${cfg.database.host};
        ''; 

      unitConfig = {
        After = [ "mysql.service" ];
        Requires = [ "mysql.service" ];
      };

      serviceConfig = {
        User = "root";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
