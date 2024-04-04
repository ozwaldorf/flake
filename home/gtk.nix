{ pkgs, username, ... }:
let
  homeDirectory = "/home/${username}";
in
{
  gtk = {
    enable = true;
    theme = {
      package = pkgs.carburetor-gtk;
      name = "Catppuccin-Mocha-Standard-Blue-Dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    gtk3.bookmarks = [
      "file://${homeDirectory}/Code"
      "file://${homeDirectory}/Downloads"
      "file://${homeDirectory}/Documents"
      "file://${homeDirectory}/Music"
      "file://${homeDirectory}/Pictures"
    ];
  };

  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 48;
    gtk.enable = true;
    x11.enable = true;
  };
}
