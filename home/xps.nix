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
    inputs.vicinae.homeManagerModules.default

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
      beekeeper-studio
      prismlauncher
    ];
  };

  # overrides
  wayland.windowManager.hyprland.settings.decoration.blur = with pkgs.lib; {
    size = mkForce 20;
    passes = mkForce 3;
    noise = mkForce "0.08";
    # contrast = "0.9";
    # brightness = "0.9";
    # popups = true;
    # xray = false;
    new_optimizations = mkForce false;
  };

  programs.home-manager.enable = true;
}
