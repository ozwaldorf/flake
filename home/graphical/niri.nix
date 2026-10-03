{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  palette = (lib.importJSON "${inputs.carburetor}/whiskers.json").mocha;
  color = name: "#${palette.${name}}";

  # Tiling to floating keeps the window's tiled size, so the new float is
  # sized and centered explicitly. Floating back to tiling is left alone, since
  # setting a width there would resize the column instead.
  toggleFloat = pkgs.writeShellApplication {
    name = "niri-toggle-float";
    runtimeInputs = [
      pkgs.niri
      pkgs.jq
    ];
    text = ''
      niri msg action toggle-window-floating
      if [ "$(niri msg -j focused-window | jq '.is_floating')" = true ]; then
        niri msg action set-window-width 800
        niri msg action set-window-height 500
        niri msg action center-window
      fi
    '';
  };

  spawn = cmd: { spawn-sh = cmd; };

  workspaceBinds = lib.listToAttrs (
    lib.concatMap (
      ws:
      let
        key = toString (lib.mod ws 10);
      in
      [
        (lib.nameValuePair "Mod+${key}" { focus-workspace = ws; })
        (lib.nameValuePair "Mod+Shift+${key}" { move-window-to-workspace = ws; })
      ]
    ) (lib.range 1 10)
  );
in
{
  home.packages = with pkgs; [
    wl-clipboard
    libnotify
    yad
  ];

  programs.zsh.shellAliases.displays = "niri msg action power-off-monitors";

  wayland.windowManager.niri = {
    enable = true;
    # The NixOS module installs the session units and portals
    systemd.enable = false;
    portalPackage = null;

    settings = {
      hotkey-overlay.skip-at-startup = { };
      # The shell runs its own on the rail's corner pixel; niri's fired on
      # every reach for the control centre in the corner beside it
      gestures.hot-corners.off = { };
      # Workspaces are transparent over the wallpaper, so a shadow would only
      # outline empty space in the overview
      overview.workspace-shadow.off = { };
      # Screenshots only go to the clipboard
      screenshot-path = null;

      input = {
        keyboard.xkb.layout = "us";
        touchpad = {
          tap = { };
          dwt = { };
        };
        warp-mouse-to-focus = { };
        # Hovering a partially visible column focuses it without panning
        focus-follows-mouse._props.max-scroll-amount = "0%";
      };

      cursor = {
        xcursor-theme = config.home.pointerCursor.name;
        xcursor-size = config.home.pointerCursor.size;
      };

      layout = {
        # 10 between windows, 20 at the screen edges
        gaps = 10;
        struts = {
          left = 10;
          right = 10;
          top = 10;
          bottom = 10;
        };
        default-column-width.proportion = 0.5;
        # Patched to center any set of columns that fits on screen together
        always-center-single-column = { };
        # Workspaces slide over the wallpaper in the backdrop instead of
        # carrying it with them, which leaves the shell's parallax to move it
        background-color = "transparent";
        focus-ring.off = { };
        border = {
          on = { };
          width = 1;
          active-color = color "text";
          inactive-color = color "base";
        };
        tab-indicator = {
          active-color = color "sky";
          inactive-color = color "sapphire";
        };
      };

      blur = {
        passes = 3;
        offset = 8;
        noise = 2.0e-2;
        saturation = 1.0;
      };

      # OutQuint, shared with the shell's own fades and slides
      animations.workspace-switch = {
        duration-ms = 400;
        curve = [
          "cubic-bezier"
          0.22
          1.0
          0.36
          1.0
        ];
      };

      binds = {
        "Mod+D" = spawn "vicinae toggle";
        "Mod+Return" = spawn "foot";
        "Mod+Shift+Return" = spawn "foot -a float";
        "Mod+E" = spawn "firefox";
        # Any input powers the monitors back on
        "Mod+L".power-off-monitors = { };
        # The veil is a surface quickshell owns, not a compositor feature
        "Ctrl+Escape" = spawn "qs ipc call drawer toggle settings";
        "Mod+V" = spawn "qs ipc call veil toggle";
        "Mod+W" = spawn "qs ipc call wallpaper next";
        "Mod+R" = spawn "export APP=$(yad --entry --text 'nix-shell -p') && nix-shell -p $APP --run $APP";

        "Print".screenshot-window._props = {
          write-to-disk = false;
          show-pointer = true;
        };
        "Shift+Print".screenshot._props.show-pointer = true;
        "Ctrl+Print" = spawn "qs ipc call recorder toggle";

        "Mod+Shift+E".quit._props.skip-confirmation = true;
        "Mod+Shift+Q".close-window = { };
        "Mod+Shift+Space".spawn = lib.getExe toggleFloat;
        "Mod+F".fullscreen-window = { };
        "Mod+Escape".toggle-overview = { };
        # QMK grave escape sends grave while gui is held
        "Mod+Grave".toggle-overview = { };

        # Tabbed columns stand in for groups
        "Mod+G".toggle-column-tabbed-display = { };
        "Mod+Tab".focus-window-down-or-top = { };
        "Mod+Shift+Tab".focus-window-up-or-bottom = { };
        "Mod+Ctrl+Left".consume-or-expel-window-left = { };
        "Mod+Ctrl+Right".consume-or-expel-window-right = { };

        # Pan the view by one column. Mod with the middle button drags the
        # view, and Mod with the left and right buttons move and resize.
        "Mod+WheelScrollDown".focus-column-right = { };
        "Mod+WheelScrollUp".focus-column-left = { };

        "Mod+Left".focus-column-or-monitor-left = { };
        "Mod+Right".focus-column-or-monitor-right = { };
        "Mod+Up".focus-window-or-monitor-up = { };
        "Mod+Down".focus-window-or-monitor-down = { };
        "Mod+Shift+Left".move-column-left-or-to-monitor-left = { };
        "Mod+Shift+Right".move-column-right-or-to-monitor-right = { };
        "Mod+Shift+Up".move-window-up = { };
        "Mod+Shift+Down".move-window-down = { };
      }
      // workspaceBinds;

      _children = [
        # Laptop panel on the left, external monitor to its right
        {
          output = {
            _args = [ "eDP-1" ];
            position._props = {
              x = 0;
              y = 0;
            };
          };
        }
        {
          output = {
            _args = [ "DP-2" ];
            position._props = {
              x = 1707;
              y = 0;
            };
          };
        }
        {
          window-rule._children = [
            { geometry-corner-radius = 10; }
            { clip-to-geometry = true; }
            # The border is otherwise a solid fill behind the window, which
            # hides the blur through translucent windows
            { draw-border-with-background = false; }
            # Blur what is actually behind the window rather than only the
            # wallpaper; patched niri falls back to xray where it cannot
            {
              background-effect = {
                blur = true;
                xray = false;
              };
            }
            { popups.background-effect.blur = true; }
          ];
        }
        # foot -a float
        {
          window-rule._children = [
            { match._props.app-id = "^float$"; }
            { open-floating = true; }
          ];
        }
        # waydroid maps at android's phone-sized default and never resizes itself
        {
          window-rule._children = [
            { match._props.app-id = "^Waydroid$"; }
            { open-floating = true; }
            { default-column-width.fixed = 1200; }
            { default-window-height.fixed = 800; }
          ];
        }
        {
          layer-rule._children = [
            { match._props.namespace = "^vicinae$"; }
            { background-effect.blur = true; }
          ];
        }
        {
          layer-rule._children = [
            { match._props.namespace = "^quickshell-wallpaper$"; }
            { place-within-backdrop = true; }
          ];
        }
        # Layers blur what is actually behind them rather than only the
        # wallpaper, whether niri or the client asks for the blur
        { layer-rule.background-effect.xray = false; }
      ];
    };
  };
}
