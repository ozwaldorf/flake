{ inputs, pkgs, ... }: {
  imports = [ inputs.ags.homeManagerModules.default ];

  programs.ags = {
    enable = true;
    configDir = ../ags;
    extraPackages = with pkgs; [
      libdbusmenu-gtk3
      brightnessctl
      playerctl
      hyprpicker
      playerctl
    ];
  };
}
