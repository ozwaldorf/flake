{
  inputs,
  pkgs,
  config,
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
    configDir = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/home/ags";
  };
}
