{ pkgs, lib, config, options, ... }:

with lib;
{
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
    ./mail.nix
  ];

  config = {
    services.qemuGuest.enable = true;

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    boot = {
      growPartition = true;
      kernelParams = [ "console=ttyS0 boot.shell_on_fail" ];
      loader.timeout = 5;
    };

    virtualisation = {
      diskSize = 8000; # MB
      memorySize = 2048; # MB
      writableStoreUseTmpfs = false;
      msize = 512000;
    };

    services.openssh.enable = true;
    services.openssh.permitRootLogin = "yes";
    #services.openssh.hostKeys = options.services.openssh.hostKeys.default;

    # we could alternatively hook root or a custom user
    # to some ssh key pair
    users.extraUsers.root.password = ""; # oops
    users.mutableUsers = false;
  };
}
