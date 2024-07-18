{ pkgs, ... }:
{
  home.packages = [ pkgs.zed-editor ];
  carburetor.zed.enable = true;
}
