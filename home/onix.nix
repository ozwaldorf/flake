{
  pkgs,
  inputs,
  username,
  homeDirectory,
  ...
}:
{
  imports = [
    # carburetor theming
    inputs.carburetor.homeManagerModules.default

    ./headless/zsh.nix # Shell
    ./headless/starship.nix # Prompt
    ./headless/git.nix # Git
    ./headless/dev.nix # Dev utils

    ./graphical/hyprland.nix # window manager
    ./graphical/gtk.nix # gtk theming
    ./graphical/ags # top bar
    ./graphical/vicinae.nix # app launcher
    ./graphical/foot.nix # Terminal
    ./graphical/vesktop # discord
    ./graphical/zed.nix # zed editor
  ];

  home = {
    inherit username homeDirectory;
    stateVersion = "24.05";
    packages = with pkgs; [
      lutgen
      lutgen-studio
      weechat
      beekeeper-studio
      prismlauncher
    ];
  };

  programs.home-manager.enable = true;
}
