# TODO: I haven't even tested this
# Source: https://christine.website/blog/paranoid-nixos-2021-07-18
{ lib, ... }:
with lib;
let
  fetchKeys = username: (builtins.fetchurl "https://github.com/${username}.keys");
in
{
  options = with types; {
    services.sshd = {
      userKeys = mkOption {
        type = attrsOf str;
        default = {};
        description = "Attributes of system user to github username so authorized keys are fetched from there";
        example = ''
        {
          haf = "huuff";
        };
        '';
      };
    };
  };

  config = mkMerge [{
     services.openssh = {
      enable = true;
      passwordAuthentication = false;
      allowSFTP = false;
      challengeResponseAuthentication = false;
      extraConfig = ''
        AllowTcpForwarding yes
        X11Forwarding no
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        AuthenticationMethods publickey
      '';
    }; }] ++ 
    (mapAttrsToList (systemUser: githubUser: { users.users.${systemUser}.authorizedKeys.keys = [ (fetchKeys githubUser) ]; }) config.sshd.userKeys)
    ;
}
