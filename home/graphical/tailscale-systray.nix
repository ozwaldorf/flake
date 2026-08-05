{ ... }:
{
  # Tray icon for the system level tailscale daemon. Declared here rather than
  # as a hand written unit in ~/.config/systemd/user so it is reproducible and
  # torn down with the graphical session.
  systemd.user.services.tailscale-systray = {
    Unit = {
      Description = "Tailscale system tray";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      # from the system profile: the daemon is configured in configuration.nix
      ExecStart = "/run/current-system/sw/bin/tailscale systray";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
