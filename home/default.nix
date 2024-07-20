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

    ./zsh.nix # Shell
    ./starship.nix # Prompt
    ./git.nix # Git
    ./dev.nix # Dev utils
    ./sway.nix # window manager
    ./hyprland.nix # other window manager
    ./gtk.nix # gtk theming
    ./ags # bar, app launcher
    ./wezterm # terminal
    ./webcord.nix # discord
    ./zed.nix # zed editor
  ];

  programs.home-manager.enable = true;

  home = {
    inherit username homeDirectory;
    stateVersion = "24.05";
    packages = with pkgs; [ lutgen ];
  };
}
