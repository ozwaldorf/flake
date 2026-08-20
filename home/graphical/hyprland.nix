{ lib, pkgs, ... }:
let
  mod = "SUPER";
  toggle_displays_cmd = "HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | xq '.[0].instance' -r) hyprctl dispatch dpms toggle";

  inherit (lib.generators) mkLuaInline;

  # theme palette, provided by carburetor as a lua module. required inline since
  # home-manager emits extraConfig after the settings that reference it.
  theme = ''require("themes.carburetor-regular")'';
  color = name: mkLuaInline "${theme}.${name}";

  bind = key: dispatcher: {
    _args = [
      key
      dispatcher
    ];
  };
  exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON cmd})";
  capture = action: mkLuaInline "function() hl.plugin.hyprcapture.${action} end";

  workspaceBinds = builtins.concatMap (
    x:
    let
      ws = toString (x + 1);
      key = toString ((x + 1) - ((x + 1) / 10 * 10));
    in
    [
      (bind "${mod} + ${key}" (mkLuaInline "hl.dsp.focus({ workspace = ${ws} })"))
      (bind "${mod} + SHIFT + ${key}" (mkLuaInline "hl.dsp.window.move({ workspace = ${ws} })"))
    ]
  ) (builtins.genList (x: x) 10);

  directionBinds =
    builtins.concatMap
      (dir: [
        (bind "${mod} + ${dir}" (mkLuaInline "hl.dsp.focus({ direction = ${builtins.toJSON dir} })"))
        (bind "${mod} + SHIFT + ${dir}" (
          mkLuaInline "hl.dsp.window.move({ direction = ${builtins.toJSON dir}, group_aware = true })"
        ))
      ])
      [
        "left"
        "right"
        "up"
        "down"
      ];
in
{
  home.packages = with pkgs; [
    wl-clipboard
    # hyprcapture's runtime tools: ffmpeg backs the animated formats, libnotify
    # its notifications. gpu-screen-recorder comes from the system module
    # instead, which pairs it with the capability wrapper its kms server needs.
    ffmpeg
    libnotify

    hyprlock
    yad
  ];

  programs.zsh.shellAliases.displays = toggle_displays_cmd;

  carburetor.themes = {
    hyprland.enable = true;
    hyprlock.enable = true;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    # uwsm owns the session; its own units handle the activation environment
    systemd.enable = false;
    plugins = [ pkgs.hyprcapture ];
    settings = {
      config = {
        debug.disable_logs = false;
        general = {
          layout = "dwindle";
          col = {
            active_border = color "text";
            inactive_border = color "base";
          };
        };
        dwindle = {
          preserve_split = true;
        };
        group = {
          col = {
            border_inactive = color "sapphire";
            border_active = color "sky";
          };
          groupbar = {
            enabled = true;
            text_color = color "text";
            priority = 0;
            col = {
              active = color "base";
              inactive = color "crust";
            };
          };
        };
        decoration = {
          blur = {
            size = 8;
            passes = 3;
            noise = 0.02;
            contrast = 0.9;
            brightness = 0.9;
            popups = true;
            xray = false;
            new_optimizations = false;
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
        plugin.hyprcapture = {
          default_mode = "region";
          # matches the old hyprshot binds, which only ever copied
          save = false;
          clipboard = true;
          # the result overlay hangs around after every capture; the clipboard
          # copy still happens without it, and the tile reports what was saved
          show_thumbnail = false;
          record_save_dir = "$XDG_VIDEOS_DIR";
          record_filename_template = "screen-recording-%Y%m%d-%H%M%S.mp4";
          # notifications go through the shell's daemon rather than hyprland's
          # own overlay, which draws over fullscreen windows
          notification_backend = "system";
          # bake the cursor into screenshots and recordings; the overlay's own
          # crosshair is never included
          include_cursor = true;
        };
      };

      # A layer's blur is drawn at its fade alpha, and its radius scales with
      # that same value, so these are what make the idle veil dissolve in
      # rather than snap on. Speed is in hyprland's units of roughly a
      # centisecond, so 2.0 lands on the shell's own 200ms fade.
      #
      # Set on the layer nodes rather than on fade itself: windows keep the
      # default, and only layer surfaces (the veil, the rail, its modals) take
      # this timing.
      animation = [
        {
          _args = [
            {
              leaf = "fadeLayersIn";
              enabled = true;
              speed = 2.0;
              bezier = "easeOutQuint";
            }
          ];
        }
        {
          _args = [
            {
              leaf = "fadeLayersOut";
              enabled = true;
              speed = 2.0;
              bezier = "easeOutQuint";
            }
          ];
        }
      ];

      # Matches the OutQuint the shell eases its own fades and slides with, so
      # the compositor's blur ramp and the surface's contents arrive together.
      curve = [
        {
          _args = [
            "easeOutQuint"
            {
              type = "bezier";
              points = [
                [
                  0.22
                  1.0
                ]
                [
                  0.36
                  1.0
                ]
              ];
            }
          ];
        }
      ];

      # uwsm waits for these before letting the session come up, and the
      # hyprland.start hook fires too late (first render frame) to satisfy it.
      # quickshell and tailscale-systray are started by their own systemd units.
      exec_cmd = [ "uwsm finalize WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE" ];

      workspace_rule =
        let
          # css gaps: vertical (top/bottom) and horizontal (left/right)
          gaps = v: h: {
            top = v;
            bottom = v;
            left = h;
            right = h;
          };
        in
        [
          {
            workspace = "m[0] w[t1]";
            gaps_out = gaps 80 80;
          }
          {
            workspace = "m[0] w[t2]";
            gaps_out = gaps 40 40;
          }
          # On widescreen monitor, pad 1 and 2 wide workspaces
          {
            workspace = "m[1] w[t1]";
            gaps_out = gaps 80 600;
          }
          {
            workspace = "m[1] w[t2]";
            gaps_out = gaps 40 300;
          }
        ];

      layer_rule = [
        {
          match.namespace = "vicinae";
          blur = true;
        }
        {
          match.namespace = "vicinae";
          ignore_alpha = 0;
        }
      ];

      window_rule = [
        # foot -a float
        {
          match.class = "float";
          float = true;
        }
        # waydroid maps at android's phone-sized default and never resizes itself
        {
          match.class = "Waydroid";
          float = true;
        }
        {
          match.class = "Waydroid";
          size = "1200 800";
        }
        {
          match.class = "Waydroid";
          center = true;
        }
      ];

      bind = [
        # App launcher
        (bind "${mod} + D" (exec "vicinae toggle"))
        # Terminal
        (bind "${mod} + RETURN" (exec "foot"))
        (bind "${mod} + SHIFT + RETURN" (exec "foot -a float"))
        # Browser
        (bind "${mod} + E" (exec "firefox"))
        # Toggle displays
        (bind "${mod} + L" (mkLuaInline "hl.dsp.dpms({ action = \"toggle\" })"))
        # Toggle the idle veil. Goes through the shell's ipc rather than a
        # dispatcher: the veil is a surface quickshell owns, not a compositor
        # feature.
        (bind "${mod} + V" (exec "qs ipc call veil toggle"))

        # Screenshots. Lua calls rather than a dispatcher string: the lua config
        # parser reads "hyprcapture:open" as lua syntax and never reaches the
        # plugin. Wrapped in functions because home-manager emits the binding
        # inline, so a bare call would run once at load and bind the key to its
        # return value.
        (bind "Print" (capture "open(\"window\")"))
        (bind "SHIFT + Print" (capture "open(\"region\")"))
        (bind "CTRL + Print" (capture "record_toggle()"))

        # Cycle wallpaper
        (bind "${mod} + W" (exec "qs ipc call wallpaper next"))

        # Nix run
        (bind "${mod} + R" (
          exec "bash -c 'export APP=$(yad --entry --text \"nix-shell -p\") && nix-shell -p $APP --run $APP'"
        ))

        # Window management
        (bind "${mod} + SHIFT + E" (mkLuaInline "hl.dsp.exit()"))
        (bind "${mod} + SHIFT + Q" (mkLuaInline "hl.dsp.window.close()"))
        (bind "${mod} + J" (mkLuaInline "hl.dsp.layout(\"togglesplit\")"))
        (bind "${mod} + SHIFT + Space" (mkLuaInline "hl.dsp.window.float({ action = \"toggle\" })"))
        (bind "${mod} + SHIFT + Space" (mkLuaInline "hl.dsp.window.resize({ x = 800, y = 500 })"))
        (bind "${mod} + SHIFT + Space" (mkLuaInline "hl.dsp.window.center()"))
        (bind "${mod} + F" (mkLuaInline "hl.dsp.window.fullscreen({ action = \"toggle\" })"))
        (bind "${mod} + P" (mkLuaInline "hl.dsp.window.pin({ action = \"toggle\" })"))

        # Groups
        (bind "${mod} + G" (mkLuaInline "hl.dsp.group.toggle()"))
        (bind "${mod} + Tab" (mkLuaInline "hl.dsp.group.next()"))
        (bind "${mod} + SHIFT + Tab" (mkLuaInline "hl.dsp.group.prev()"))
        (bind "${mod} + CTRL + Left" (mkLuaInline "hl.dsp.group.move_window({ forward = false })"))
        (bind "${mod} + CTRL + Right" (mkLuaInline "hl.dsp.group.move_window({ forward = true })"))

        # Mouse move/resize
        {
          _args = [
            "${mod} + mouse:272"
            (mkLuaInline "hl.dsp.window.drag()")
            { mouse = true; }
          ];
        }
        {
          _args = [
            "${mod} + mouse:273"
            (mkLuaInline "hl.dsp.window.resize()")
            { mouse = true; }
          ];
        }
      ]
      # Window traversal and movement
      ++ directionBinds
      # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
      ++ workspaceBinds;
    };
  };
}
