{ inputs, pkgs, ... }:
{
  imports = [ inputs.ags.homeManagerModules.default ];

  home.packages = with pkgs; [
    libdbusmenu-gtk3
    brightnessctl
    playerctl
    hyprpicker
    playerctl
    sassc
  ];

  programs.ags = {
    enable = true;
    configDir = ../ags;
  };
}
