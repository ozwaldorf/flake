{ pkgs, username, homeDirectory, nvim, ... }: {
  imports = [
    ./sway.nix # window manager
    ./hyprland.nix
    ./gtk.nix # gtk theming
    ./ags # bar, app launcher
    ./wezterm # terminal
    ./zsh.nix # Shell
    ./starship.nix # prompt
    ./git.nix # git
    ./dev.nix # dev utils
  ];

  home = {
    inherit username homeDirectory;

    sessionVariables = {

      EDITOR = "nvim";
    };

    packages = with pkgs; [
      nvim
      webcord
      pavucontrol
      wdisplays

      gnome.eog # photo viewer
      gnome.totem # video player
      gnome.evince # document viewer
      gnome.file-roller # archive manager
      gnome.nautilus # file explorer
      gnome.simple-scan # document scanner
      gnome.gnome-characters
      gnome.gnome-font-viewer
      gnome.gnome-system-monitor
      gnome.gnome-disk-utility
    ];

    stateVersion = "24.05";
  };

  programs.home-manager.enable = true;
}
