{ pkgs, username, ... }:
let
  homeDirectory = "/home/${username}";
in
{
  imports = [ ./modules/pointer.nix ];

  gtk = {
    enable = true;
    theme = {
      package = pkgs.carburetor-gtk;
      name = "carburetor";
    };
    iconTheme = {
      package = pkgs.carburetor-papirus-folders;
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

  home.pointerCursorPatch = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 48;
    x11.enable = true;
    gtk = {
      enable = true;
      size = 24;
    };
  };
}
