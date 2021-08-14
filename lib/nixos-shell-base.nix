{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    php74 
    vim
    telnet
  ];
}
