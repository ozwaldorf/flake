{ pkgs, options, ... }:
let
  mod = "SUPER";
  toggle_displays_cmd = "HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | xq '.[0].instance' -r) hyprctl dispatch dpms toggle";
in
{
  home.packages = with pkgs; [
    wl-clipboard
    wf-recorder
    sway-contrib.grimshot

    hyprlock
    hyprshot
    yad
  ];

  programs.zsh.shellAliases.displays = toggle_displays_cmd;

  carburetor.themes = {
    hyprland.enable = true;
    hyprlock.enable = true;
  };

  # wallpaper daemon
  services.awww.enable = true;

  # notification daemon
  services.mako = {
    enable = true;
    settings = {
      font = "Berkeley Mono 10";
      background-color = "#161616";
      text-color = "#f4f4f4";
      border-color = "#4589ff";
      progress-color = "over #262626";
      "urgency=low" = {
        border-color = "#393939";
      };
      "urgency=high" = {
        border-color = "#fa4d56";
        default-timeout = 0;
      };

      border-size = 2;
      border-radius = 10;
      padding = 12;
      margin = 10;
      default-timeout = 0;
      max-icon-size = 48;

      # pin to laptop top left
      layer = "overlay";
      anchor = "top-left";
      output = "eDP-1";

    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    # plugins = with pkgs.hyprlandPlugins; [
    # hyprexpo
    # hyprtrails
    # hypr-dynamic-cursors
    # ];
    settings = {
      # plugins = {
      #   hyprexpo = {
      #     columns = 2;
      #     gap_size = 20;
      #     bg_col = "rgb(161616)";
      #     workspace_method = "first 1";
      #   };
      #   hyprtrails = {
      #     color = "rgba(4589ffcc)";
      #   };
      #   dynamic-cursors = {
      #     shake = {
      #       threshold = 4.0;
      #       effects = true;
      #     };
      #     hyprcursor = {
      #       nearest = 0;
      #     };
      #   };
      # };
      debug.disable_logs = false;
      exec-once = [
        "tailscale systray"
        "mako"
      ];
      source = [ "./themes/regular.conf" ];
      # monitor = [ "Unknown-1, disable" ];
      general = {
        layout = "dwindle";
        "col.active_border" = "$text";
        "col.inactive_border" = "$base";
      };
      workspace = [
        "m[0] w[t1], gapsout:80 80"
        "m[0] w[t2], gapsout:40 40"
        # On widescreen monitor, pad 1 and 2 wide workspaces
        "m[1] w[t1], gapsout:80 600"
        "m[1] w[t2], gapsout:40 300"
      ];
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      group = {
        "col.border_inactive" = "$sapphire";
        "col.border_active" = "$sky";
        groupbar = {
          enabled = true;
          text_color = "$text";
          priority = 0;
          "col.active" = "$base";
          "col.inactive" = "$crust";
        };
      };
      decoration = {
        blur = {
          size = 8;
          passes = 3;
          noise = "0.02";
          contrast = "0.9";
          brightness = "0.9";
          popups = true;
          xray = false;
          new_optimizations = false;
        };
        rounding = 10;
        dim_special = "0.0";
      };
      misc = {
        disable_hyprland_logo = true;
        animate_manual_resizes = false;
        animate_mouse_windowdragging = false;
        close_special_on_empty = true;
      };
      layerrule = [
        # "blur,bar*"
        # "ignorealpha,bar*"
        # "blur,quicksettings*"
        # "ignorealpha,quicksettings*"
        # "blur,notifications*"
        # "ignorealpha,notifications*"
        "blur on, match:namespace vicinae"
        "ignore_alpha 0, match:namespace vicinae"
      ];
      # windowrule = [ "size 800 500, floating:1" ];
      windowrulev2 = [
        # "float,class:float"
        # "center,class:float"
        # "size 50% 30%,class:float"
        # "float,class:yad"
        # "center,class:yad"
        # "size 35 80,class:yad"
        # "float,class:firefox,title:(.*)(MetaMask)(.*)"
        # "center,class:firefox,title:(.*)(MetaMask)(.*)"
      ];
      bindm = [
        "${mod},mouse:272,movewindow"
        "${mod},mouse:273,resizewindow"
      ];
      bind = [
        # "${mod}, grave, hyprexpo:expo, toggle"

        # App launcher
        "${mod}, D, exec, vicinae toggle"
        # Terminal
        "${mod}, RETURN, exec, foot"
        "${mod} SHIFT, RETURN, exec, foot -a float"
        # Browser
        "${mod}, E, exec, firefox"
        # Toggle displays
        "${mod}, L, dpms, toggle"

        # Screenshots
        ", Print, exec, hyprshot --clipboard-only -zm window"
        "SHIFT, Print, exec, hyprshot --clipboard-only -zm region"

        # Cycle wallpaper
        "${mod}, W, exec, bash -c 'swww img --transition-type any $(find ~/Pictures/walls/carburetor | shuf -n 1)'"

        # Nix run
        "${mod}, R, exec, bash -c 'export APP=$(yad --entry --text \"nix-shell -p\") && nix-shell -p $APP --run $APP'"

        # Window management
        "${mod} SHIFT, E, exit"
        "${mod} SHIFT, Q, killactive"
        "${mod}, J, togglesplit"
        "${mod} SHIFT, Space, togglefloating"
        "${mod} SHIFT, Space, resizeactive, exact 800 500"
        "${mod} SHIFT, Space, centerwindow"
        "${mod}, F, fullscreen"
        "${mod}, P, pin"
        # "${mod} SHIFT, F, fullscreenstate -1 2"

        # Groups
        "${mod}, G, togglegroup"
        "${mod}, Tab, changegroupactive, f"
        "${mod}, Shift, changegroupactive, b"
        "${mod} CTRL, Left, movegroupwindow, b"
        "${mod} CTRL, Right, movegroupwindow"

        # Window traversal and movement
        "${mod}, left, movefocus, l"
        "${mod}, right, movefocus, r"
        "${mod}, up, movefocus, u"
        "${mod}, down, movefocus, d"
        "${mod} SHIFT, left, movewindoworgroup, l"
        "${mod} SHIFT, right, movewindoworgroup, r"
        "${mod} SHIFT, up, movewindoworgroup, u"
        "${mod} SHIFT, down, movewindoworgroup, d"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
        builtins.concatLists (
          builtins.genList (
            x:
            let
              ws =
                let
                  c = (x + 1) / 10;
                in
                builtins.toString (x + 1 - (c * 10));
            in
            [
              "${mod}, ${ws}, workspace, ${toString (x + 1)}"
              "${mod} SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]
          ) 10
        )
      );
    };
  };
}
