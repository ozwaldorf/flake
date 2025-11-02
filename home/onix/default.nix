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

    ../shared/zsh.nix # Shell
    ../shared/starship.nix # Prompt
    ../shared/git.nix # Git
    ../shared/dev.nix # Dev utils

    ./hyprland.nix # window manager
    ./gtk.nix # gtk theming
    ./ags # bar, app launcher
    ./foot.nix # Terminal
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
