{ ... }: {
  wayland.windowManager.hyprland = let mod = "SUPER";
  in {
    enable = true;
    settings = {
      exec = [ "swww init" "ags" ];
      decoration = {
        blur = {
          size = 8;
          passes = 3;
          xray = false;
          popups = true;
          noise = "0.02";
          contrast = 0.9;
          brightness = 0.9;
        };

        rounding = 10;
        dim_special = 0.0;
      };
      misc = {
        disable_hyprland_logo = true;
        animate_manual_resizes = false;
        animate_mouse_windowdragging = false;
        close_special_on_empty = true;
      };
      bind = [
        "${mod}, RETURN, exec, wezterm"
        "${mod}, E, exec, firefox"
        ", Print, exec, grimshot copy anything"
        "${mod}, J, togglesplit"
        "${mod}, D, exec, ags -t applauncher"
        "${mod} SHIFT, Q, killactive"
        "${mod} SHIFT, E, exit"
        "${mod} SHIFT, Space, togglefloating"
        "${mod}, left, movefocus, l"
        "${mod}, left, movefocus, l"
        "${mod}, right, movefocus, r"
        "${mod}, up, movefocus, u"
        "${mod}, down, movefocus, d"
        "${mod} SHIFT, left, movewindow, l"
        "${mod} SHIFT, right, movewindow, r"
        "${mod} SHIFT, up, movewindow, u"
        "${mod} SHIFT, down, movewindow, d"
        "${mod}, mouse:272, moveactive"
        "${mod}, mouse:273, resizeactive"
      ] ++ (
        # workspaces
        # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
        builtins.concatLists (builtins.genList (x:
          let
            ws = let c = (x + 1) / 10; in builtins.toString (x + 1 - (c * 10));
          in [
            "${mod}, ${ws}, workspace, ${toString (x + 1)}"
            "${mod} SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
          ]) 10));

    };
  };
}
