{ pkgs, ... }:
# TODO: Some names as in options so I can use inherit??
let
  domain = "example.com";
  user1Address = "user1@${domain}";
  user2Address = "user2@${domain}";
  installationPath = "/var/lib/postfix";
  testContent = "test content";
  testSubject = "test subject";
  vmailPath = "/var/lib/vmail";
in
pkgs.nixosTest {
  name = "postfix-virtual";

  machine = { pkgs, ... }: {
    imports = [
      ../default.nix
    ];

    environment.systemPackages = with pkgs; [ mailutils ];

    machines.postfix = {
      enable = true;
      restrictions = "rfc_conformant";
      canonicalDomain = domain;

      maps.virtual_mailbox_maps.path = installationPath;

      mailPath = vmailPath;

      users = [
        user1Address
        user2Address
      ];
    };

  };

  testScript = ''
    ${ builtins.readFile ../../../lib/testing-lib.py }

    machine.wait_for_unit("multi-user.target")

    with subtest("unit is active"):
      machine.succeed("systemctl is-active --quiet postfix")

    with subtest("virtual mailbox map works"):
      machine.succeed("postalias -q ${user1Address} hash:${installationPath}/virtual_mailbox_maps")
      machine.succeed("postalias -q ${user2Address} hash:${installationPath}/virtual_mailbox_maps")
      # Sanity check
      machine.fail("postalias -q pepo hash:${installationPath}/virtual_mailbox_maps")

    with subtest("can send and receive email from local"):
      machine.succeed('echo "${testContent}" | mail -u ${user1Address} -s "${testSubject}" ${user2Address}')
      machine.sleep(1)
      machine.output_contains('echo p | mail -f ${vmailPath}/${user2Address}/', "To: <${user2Address}>")
      machine.output_contains('echo p | mail -f ${vmailPath}/${user2Address}/', "Subject: ${testSubject}")
      machine.output_contains('echo p | mail -f ${vmailPath}/${user2Address}/', "${testContent}")

  '';
}
