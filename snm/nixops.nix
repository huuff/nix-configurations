{
  network.description = "Simple NixOS mailserver";

  mailserver = import ./mail.nix;
}

