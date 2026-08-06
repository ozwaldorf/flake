{ config, pkgs, ... }:
{
  # socat reads hyprcapture's recording status socket for the recorder tile,
  # curl fetches site icons for players that publish no cover art
  home.packages = [
    pkgs.quickshell
    pkgs.socat
    pkgs.curl
  ];

  # symlinked out of the store so quickshell's live reload sees edits to the
  # working tree; a store copy would be read only and need a rebuild per change
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/nixos/home/graphical/quickshell";

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell desktop shell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
