{ pkgs, doOnRequest, neuronPkg, ... }:
let
  user1 = {
    name = "user1";
    pass = "user1pass";
    email = "user1@example.com";
  };
  user2 = {
    name = "user2";
    pass = "user2pass";
    email = "user2@example.com";
  };
  databasePassword = "dbpass";
in
pkgs.nixosTest {
  name = "wallabag";

  machine = { pkgs, ... }: {
    imports = [ ./default.nix ];

    services.wallabag = {
      services.wallabag = {
        enable = true;
        ssl.enable = false;

        database.passwordFile = pkgs.writeText databasePassword;

        users = [
          {
            username = user1.name;
            passwordFile = pkgs.writeText user1.pass;
            email = user1.email;
          }
          {
            username = user2.name;
            passwordFile = pkgs.writeText user2pass;
            email = user2.email;
          }
        ];
      };
    };
  };

  testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("units are active"):
        machine.succeed("systemctl is-active --quiet copy-wallabag")
        machine.succeed("systemctl is-active --quiet create-parameters")
        machine.succeed("systemctl is-active --quiet install-wallabag")
        machine.succeed("systemctl is-active --quiet setup-users")

      with subtest("nginx is serving wallabag"):
        [ _, out ] = machine.execute('curl localhost')
        assert '<title>Welcome to wallabag! – wallabag</title>' in out

      with subtest("default user is correctly deactivated"):
      # TODO 
  '';
}
