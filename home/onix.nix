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

    ./graphical/niri.nix # window manager
    ./graphical/gtk.nix # gtk theming
    ./graphical/quickshell.nix # bar and notifications
    ./graphical/idle.nix # dim and blank when idle
    ./graphical/tailscale-systray.nix # vpn tray icon
    ./graphical/rio.nix # Terminal
    ./graphical/vesktop # discord
    ./graphical/zed.nix # zed editor
  ];

  home = {
    inherit username homeDirectory;
    stateVersion = "24.05";
    packages = with pkgs; [
      lutgen
      beekeeper-studio
      prismlauncher
      eden
      gimp
      kdePackages.kdenlive
      nvtopPackages.full
    ];
  };

  programs.home-manager.enable = true;
}
