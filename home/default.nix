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

    ./foot.nix # Terminal
    ./zsh.nix # Shell
    ./starship.nix # Prompt
    ./git.nix # Git
    ./dev.nix # Dev utils

    ./hyprland.nix # window manager
    ./gtk.nix # gtk theming
    ./ags # bar, app launcher
    ./vesktop # discord
    ./zed.nix # zed editor
  ];

  home = {
    inherit username homeDirectory;
    stateVersion = "24.05";
    packages = with pkgs; [
      lutgen
      beekeeper-studio
      prismlauncher
    ];
  };

  programs.home-manager.enable = true;
}
