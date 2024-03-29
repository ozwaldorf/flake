{ pkgs, username, homeDirectory, ... }: {
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

    sessionVariables = { EDITOR = "nvim"; };

    packages = with pkgs; [
      neovim
      lutgen
      webcord # discord
      pavucontrol # volume control
      wdisplays # display control
      gnome.eog # photo viewer
      gnome.totem # video player
      gnome.evince # document viewer
      gnome.file-roller # archive manager
      gnome.nautilus # file explorer
      gnome.simple-scan # document scanner
      gnome.gnome-characters # character viewer
      gnome.gnome-font-viewer # font viewer
      gnome.gnome-system-monitor # resource monitor
      gnome.gnome-disk-utility # disk manager
    ];

    stateVersion = "24.05";
  };

  programs.home-manager.enable = true;
}
