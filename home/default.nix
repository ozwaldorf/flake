{
  pkgs,
  username,
  homeDirectory,
  ...
}:
{
  imports = [
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
  ];

  programs.home-manager.enable = true;
  home = {
    inherit username homeDirectory;
    stateVersion = "24.05";
    sessionVariables = {
      EDITOR = "nvim";
    };
    packages = with pkgs; [
      neovim
      lutgen
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
  };
}
