{ pkgs, ... }:
{
  carburetor.themes.zed.enable = true;
  home.packages = with pkgs; [
    zed-editor
    nixd
  ];
}
