{ pkgs, ... }:
{
  # enable discord ipc server
  services.arrpc.enable = true;
  carburetor.themes.webcord.enable = true;
  home.packages = [ pkgs.webcord ];
}
