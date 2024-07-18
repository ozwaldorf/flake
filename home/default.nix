{
  pkgs,
  inputs,
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
    ./zed.nix # zed editor

    # global caburetor theming
    inputs.carburetor.homeManagerModules.default
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
      # gimp-devel
      pavucontrol # volume control
      wdisplays # display control
      eog # photo viewer
      totem # video player
      evince # document viewer
      file-roller # archive manager
      nautilus # file explorer
      simple-scan # document scanner
      gnome.gnome-characters # character viewer
      gnome-font-viewer # font viewer
      gnome-system-monitor # resource monitor
      gnome-disk-utility # disk manager
    ];
  };
}
