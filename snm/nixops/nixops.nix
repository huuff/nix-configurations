{
  network.description = "Simple NixOS mailserver";

  mailserver = { config, pkgs, ...}:
  {
    imports = [ ./mail.nix ];
    deployment.keys.hashedPassword2.text = "$2y$05$uwZ.DVftxvA3IMjXCzGYq..XW.mXI0vLqIuh9exiKiu20hIB7lefq"; 
  };

}

