{
  inputs,
  pkgs,
  config,
  flakeDirectory,
  ...
}:
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
    configDir = config.lib.file.mkOutOfStoreSymlink flakeDirectory + "/home/ags";
  };
}
