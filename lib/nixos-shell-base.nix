{ pkgs, lib, config, ... }:
with lib;
{
  options = {

    forwardedPorts = mkOption {
      type = with types; attrsOf str;
      default = {};
      description = "Attribute set associating hostPort -> guestPort";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      php74 
      vim
      telnet
      ag
      fd
      fzf
    ];

    virtualisation.qemu.networkingOptions = let
      fwd = hostPort: guestPort: "hostfwd=tcp::${hostPort}-:${guestPort}";
    in
    mkIf (config.forwardedPorts != {}) [
      "-net nic,netdev=user.0,model=virtio"
      (mkIf (config.forwardedPorts != {}) "-netdev user,id=user.0,${concatStringsSep "," (mapAttrsToList fwd config.forwardedPorts)}")
    ];
  };
}
