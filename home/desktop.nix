{ pkgs, ... }: {
  imports = [
    ./sway.nix # window manager
    ./hyprland.nix # other window manager
    ./gtk.nix # gtk theming
    ./ags # bar, app launcher
    ./wezterm # terminal
    ./webcord.nix # discord
  ];

  home.packages = with pkgs; [
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
}
