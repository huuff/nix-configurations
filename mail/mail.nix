{ pkgs, ...}:
{
  services.postfix = {
    enable = true;
    virtual = ''
      contact@example.com sammy
      admin@example.com sammy
    '';
    config = {
      home_mailbox = "Maildir/";
    };
  };
}
