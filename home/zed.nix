{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zed-editor
    nixd
  ];

  carburetor.themes.zed.enable = true;
}
