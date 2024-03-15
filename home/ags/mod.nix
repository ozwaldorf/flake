{ inputs, pkgs, ... }: {
  imports = [ inputs.ags.homeManagerModules.default ];

  home.packages = with pkgs; [ brightnessctl playerctl hyprpicker playerctl ];

  programs.ags = {
    enable = true;
    configDir = ../ags;
  };
}
