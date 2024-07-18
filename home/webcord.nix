{ pkgs, ... }:
{
  home.packages = [ pkgs.webcord ];
  # enable discord ipc server
  services.arrpc.enable = true;
  carburetor.webcord.enable = true;
}
