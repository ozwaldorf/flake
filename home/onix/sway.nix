{ lib, pkgs, ... }:
{
  wayland.windowManager.sway =
    let
      mod = "Mod4";
    in
    {
      enable = true;
      checkConfig = false;
      package = pkgs.swayfx;
      config = {
        startup = [
          {
            command = "ags";
            always = true;
          }
          { command = "swww init"; }
          { command = "gnome-keyring-daemon --start"; }
          { command = "systemctl --user start polkit-gnome-authentication-agent-1"; }
        ];
        modifier = mod;
        keybindings = lib.mkOptionDefault {
          "${mod}+Return" = "exec wezterm";
          "${mod}+d" = "exec ags -t applauncher";
          "${mod}+e" = "exec firefox";
          "${mod}+Shift+r" = "reload";
          "${mod}+Shift+e" = "exit";
          "Print" = "exec grimhot copy anything";
        };
        terminal = "wezterm";
        focus.followMouse = true;
        gaps = {
          outer = 0;
          inner = 20;
        };
        bars = [ ];
      };
      extraConfig = ''
        default_border none

        # Carburetor palette    Border    BG        Text    Indicator
        client.focused          #4589ffFF #4589ffFF #161616 #4589ffFF
        client.urgent           #FF832BFF #FF832BFF #161616 #FF832BFF
        client.focused_inactive #1616167E #1616167E #f4f4f4 #1616167E
        client.unfocused        #1616167E #1616167E #f4f4f4 #1616167E

        # swayfx stuff
        corner_radius 10
        blur on
        blur_passes 3
        blur_radius 8
        shadows on
        #shadow_offset 0 0
        shadow_blur_radius 50
        shadow_color #000000FF
        #shadow_inactive_color #000000B0
      '';
    };
}
