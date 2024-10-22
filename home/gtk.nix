{ pkgs, ... }:
{
  imports = [ ./modules/pointer.nix ];

  home = {
    # Standalone gnome desktop apps
    packages = with pkgs; [
      pavucontrol # volume control
      wdisplays # display control
      gnome-system-monitor # resource monitor

      nautilus # file explorer
      simple-scan # document scanner
      torrential # torrent manager

      eog # photo viewer
      celluloid # video player
      evince # document viewer
      gnome-characters # character viewer
      gnome-font-viewer # font viewer
    ];

    pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 48;
      x11.enable = true;
      gtk = {
        enable = true;
        # size = 24;
      };
    };
  };

  gtk.enable = true;

  carburetor.themes.gtk = {
    enable = true;
    transparency = true;
    icon = true;
  };
}
