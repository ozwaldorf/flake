{ lib, pkgs, ... }:
let
  mod = "SUPER";
  toggle_displays_cmd = "HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j | xq '.[0].instance' -r) hyprctl dispatch dpms toggle";

  inherit (lib.generators) mkLuaInline;

  # theme palette, provided by carburetor as a lua module. required inline since
  # home-manager emits extraConfig after the settings that reference it.
  theme = ''require("themes.carburetor-regular")'';
  color = name: mkLuaInline "${theme}.${name}";

  bind = key: dispatcher: { _args = [ key dispatcher ]; };
  exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON cmd})";

  # Dim every panel the kernel exposes a backlight for, which after ddcci binds
  # includes external monitors. Names are not stable, so they are enumerated
  # rather than hardcoded.
  #
  # Levels go through logind, which authorises the write against the active
  # session; writing sysfs directly would need a udev rule loosening the files.
  idleDim = pkgs.writeShellApplication {
    name = "idle-dim";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/idle-dim.state"

      set_level() {
        busctl --system call org.freedesktop.login1 \
          /org/freedesktop/login1/session/auto \
          org.freedesktop.login1.Session \
          SetBrightness ssu backlight "$1" "$2" >/dev/null
      }

      case "''${1:-}" in
        dim)
          # Already dimmed: a second notification must not record the dimmed
          # level as the one to come back to.
          [ -e "$state" ] && exit 0

          : > "$state"
          for d in /sys/class/backlight/*; do
            [ -e "$d/max_brightness" ] || continue
            b="''${d##*/}"
            cur=$(cat "$d/actual_brightness")
            max=$(cat "$d/max_brightness")
            printf '%s %s\n' "$b" "$cur" >> "$state"

            # a tenth of the panel's range, and never up from where it was
            target=$(( max / 10 ))
            [ "$target" -lt "$cur" ] || target="$cur"
            set_level "$b" "$target"
          done
          ;;

        restore)
          [ -e "$state" ] || exit 0
          while read -r b level; do
            [ -n "$b" ] || continue
            set_level "$b" "$level"
          done < "$state"
          rm -f "$state"
          ;;
      esac
    '';
  };

  # Dim first, then blank: the dim warns the blank is coming and is cheap to
  # undo if you are still there. -w waits for each command, so a slow DDC write
  # cannot be overtaken by the resume that follows it.
  idleWatch = pkgs.writeShellApplication {
    name = "idle-watch";
    runtimeInputs = [
      pkgs.swayidle
      pkgs.hyprland
    ];
    text = ''
      exec swayidle -w \
        timeout 300 '${idleDim}/bin/idle-dim dim' \
        resume '${idleDim}/bin/idle-dim restore' \
        timeout 600 'hyprctl dispatch "hl.dsp.dpms({ action = \"off\" })"' \
        resume 'hyprctl dispatch "hl.dsp.dpms({ action = \"on\" })"'
    '';
  };

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

  directionBinds = builtins.concatMap (dir: [
    (bind "${mod} + ${dir}" (mkLuaInline "hl.dsp.focus({ direction = ${builtins.toJSON dir} })"))
    (bind "${mod} + SHIFT + ${dir}" (
      mkLuaInline "hl.dsp.window.move({ direction = ${builtins.toJSON dir}, group_aware = true })"
    ))
  ]) [ "left" "right" "up" "down" ];
in
{
  home.packages = with pkgs; [
    wl-clipboard
    wf-recorder
    # region selection for the shell's screen recorder; grimshot bundles its
    # own copy, but the widget calls it directly
    slurp
    sway-contrib.grimshot

    hyprlock
    hyprshot
    yad

    idleDim
  ];

  # Dims the panels after a while and blanks them after longer, restoring the
  # level that was set before the dim. Declared here rather than as a hand
  # written unit so it is torn down with the graphical session.
  systemd.user.services.idle = {
    Unit = {
      Description = "Idle dimming and blanking";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${idleWatch}/bin/idle-watch";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.zsh.shellAliases.displays = toggle_displays_cmd;

  carburetor.themes = {
    hyprland.enable = true;
    hyprlock.enable = true;
  };

  # wallpaper daemon
  services.awww.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    # uwsm owns the session; its own units handle the activation environment
    systemd.enable = false;
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
      };

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

        # Screenshots
        (bind "Print" (exec "hyprshot --clipboard-only -zm window"))
        (bind "SHIFT + Print" (exec "hyprshot --clipboard-only -zm region"))

        # Cycle wallpaper
        (bind "${mod} + W" (
          exec "bash -c 'swww img --transition-type any $(find ~/Pictures/walls/carburetor | shuf -n 1)'"
        ))

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
