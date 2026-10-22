{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  palette = (lib.importJSON "${inputs.carburetor}/whiskers.json").mocha;

  # Speaking to the shell (`desk`) and the window manager (`wm`) from a key.
  desk = cmd: "pleamar-wm --say desk \"${cmd}\"";
  wm = cmd: "pleamar-wm --say wm \"${cmd}\"";

  # Graded copies of the wallpapers: at their own size and shape, run through the
  # carburetor CLUT once, when they are first shown, instead of every frame.
  clut = pkgs.runCommand "carburetor-clut" { nativeBuildInputs = [ pkgs.lutgen ]; } ''
    mkdir -p "$out"
    lutgen generate -p carburetor -P -L 0.3 -r 10 -l 8 -o "$out/clut.png"
  '';
  fetchWallpaper = pkgs.writeShellApplication {
    name = "fetch-wallpaper";
    # The single quoted $ are jaq variables, not shell ones
    excludeShellChecks = [ "SC2016" ];
    runtimeInputs = [
      pkgs.curl
      pkgs.jaq
      pkgs.coreutils
    ];
    text = builtins.readFile ./quickshell/scripts/fetch-wallpaper.sh;
  };
  wallpaper = pkgs.writeShellApplication {
    name = "pleamar-wallpaper";
    runtimeInputs = [
      fetchWallpaper
      pkgs.lutgen
      pkgs.imagemagick
      pkgs.coreutils
    ];
    text = ''
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/pleamar/wallpaper"
      # Apart from the old 16:9 crops, which would otherwise be reused
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/pleamar/wallpaper/native"
      mkdir -p "$state" "$cache"

      # Prints the graded copy of an image, making it the first time.
      grade() {
        out="$cache/$(basename "''${1%.*}").jpg"
        if [ ! -s "$out" ]; then
          tmp=$(mktemp --suffix=.png -p "$cache")
          magick "$1" -auto-orient "$tmp" >&2
          lutgen apply --hald-clut ${clut}/clut.png "$tmp" -o "$out" >&2
          rm -f "$tmp"
        fi
        printf '%s\n' "$out"
      }

      case "''${1:-}" in
        current)
          cur=$(cat "$state/current" 2>/dev/null || true)
          if [ -n "$cur" ] && [ -r "$cur" ]; then
            grade "$cur"
          else
            exec "$0" next
          fi
          ;;
        next)
          path=$(fetch-wallpaper)
          printf '%s\n' "$path" > "$state/current"
          grade "$path"
          ;;
        set)
          [ -r "''${2:-}" ] || exit 1
          printf '%s\n' "$2" > "$state/current"
          grade "$2"
          ;;
        *)
          echo "pleamar-wallpaper current|next|set PATH" >&2
          exit 1
          ;;
      esac
    '';
  };

  # The focused window, to the clipboard, through pleamar-wm's hyprctl answers.
  shotWindow = pkgs.writeShellApplication {
    name = "pleamar-shot-window";
    runtimeInputs = [
      pkgs.grim
      pkgs.wl-clipboard-rs
      pkgs.gawk
    ];
    text = ''
      geom=$(pleamar-wm hyprctl activewindow | awk '
        /^\tat:/ { split($2, a, ","); x = a[1]; y = a[2] }
        /^\tsize:/ { split($2, s, ","); w = s[1]; h = s[2] }
        END { if (w) printf "%s,%s %sx%s", x, y, w, h }')
      [ -n "$geom" ] || exit 1
      grim -g "$geom" - | wl-copy --type image/png
    '';
  };
  shotRegion = pkgs.writeShellApplication {
    name = "pleamar-shot-region";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard-rs
    ];
    text = ''grim -g "$(slurp)" - | wl-copy --type image/png'';
  };

  # Monitors off until the next input, as niri's power-off-monitors: dark after
  # a second of quiet, and back on (and done) at the first touch.
  monitorsOff = pkgs.writeShellApplication {
    name = "pleamar-monitors-off";
    runtimeInputs = [
      pkgs.swayidle
      pkgs.wlopm
    ];
    text = ''
      # exec keeps this PID, so the resume command ends swayidle itself
      exec swayidle -w timeout 1 "wlopm --off '*'" resume "wlopm --on '*'; kill $$"
    '';
  };

  # Every binding once: keys.conf is written from it, and so is the list the
  # shell's Keys page shows.
  bind = group: key: label: action: {
    inherit
      group
      key
      label
      action
      ;
  };
  binds = [
    (bind "Launch" "Super+Return" "Terminal" "launch rio")
    (bind "Launch" "Super+Shift+Return" "Floating terminal" "launch rio --app-id float")
    (bind "Launch" "Super+e" "Browser" "launch firefox")
    (bind "Shell" "Super+d" "App launcher" "launch ${desk "emit drawer_toggle 3"}")
    (bind "Shell" "Super+Shift+d" "Clipboard history" "launch ${desk "emit drawer_toggle 4"}")
    (bind "Shell" "Super+Shift+question" "Keyboard shortcuts" "launch ${desk "emit drawer_toggle 5"}")
    (bind "Shell" "Super+Tab" "System monitor" "launch ${desk "emit drawer_toggle 2"}")
    (bind "Shell" "Super+Escape" "Overview" "launch ${desk "emit drawer_overview"}")
    # QMK grave escape sends grave while gui is held
    (bind "Shell" "Super+grave" "Overview" "launch ${desk "emit drawer_overview"}")
    (bind "Shell" "Super+v" "Toggle veil" "launch ${desk "emit veil_toggle"}")
    (bind "Shell" "Super+w" "Next wallpaper" "launch ${wm "emit wall_next"}")
    (bind "Windows" "Super+Shift+q" "Close window" "close")
    (bind "Windows" "Super+Shift+space" "Toggle floating" "toggle_float")
    (bind "Windows" "Super+f" "Fullscreen" "fullscreen")
    (bind "Windows" "Super+r" "Cycle window width" "cycle_width")
    (bind "Windows" "Super+Shift+r" "Cycle row height" "cycle_height")
    (bind "Focus" "Super+Left" "Focus window or monitor left" "focus_left")
    (bind "Focus" "Super+Right" "Focus window or monitor right" "focus_right")
    (bind "Focus" "Super+Up" "Focus row above" "focus_up")
    (bind "Focus" "Super+Down" "Focus row below" "focus_down")
    (bind "Move" "Super+Shift+Left" "Move window left or to monitor" "move_left")
    (bind "Move" "Super+Shift+Right" "Move window right or to monitor" "move_right")
    (bind "Move" "Super+Shift+Up" "Move window to row above, or a new one" "move_up")
    (bind "Move" "Super+Shift+Down" "Move window to row below, or a new one" "move_down")
    (bind "Focus" "Super+1" "Focus monitor 1" "focus_monitor 0")
    (bind "Focus" "Super+2" "Focus monitor 2" "focus_monitor 1")
    (bind "Move" "Super+Shift+1" "Move window to monitor 1" "move_monitor 0")
    (bind "Move" "Super+Shift+2" "Move window to monitor 2" "move_monitor 1")
    (bind "Capture" "Print" "Screenshot window" "launch ${lib.getExe shotWindow}")
    (bind "Capture" "Shift+Print" "Screenshot region" "launch ${lib.getExe shotRegion}")
    (bind "Capture" "Ctrl+Print" "Toggle screen recording" "launch ${desk "emit rec_toggle"}")
    (bind "Session" "Super+l" "Power off monitors" "launch ${lib.getExe monitorsOff}")
    (bind "Session" "Super+Shift+e" "Quit" "launch ${wm "quit"}")
  ];

  keysConf = lib.concatMapStringsSep "\n" (b: "bind ${b.key} ${b.action}") binds + "\n";

  # The Keys page's list.
  keybindsLuau =
    let
      entry = b: ''{ key = "${b.key}", label = "${b.label}", group = "${b.group}" },'';
    in
    ''
      -- Generated from home/graphical/pleamar.nix.
      return {
      ${lib.concatMapStringsSep "\n" (b: "    ${entry b}") binds}
      }
    '';

  sessionConf = ''
    # Laptop panel on the left, external monitor to its right. The laptop
    # (1067 tall) sits low so the external's bottom (1440) is 64 below its own.
    monitor eDP-1 2560x1600@240 at 0,309 scale 1.5
    monitor DP-2 preferred at 1707,0

    # pleamar-wm agent: a second pointer and keyboard for AI agents
    agent on

    keyboard layout us
    touchpad tap on dwt on

    # Dimmed by the idle watcher at five minutes, dark at ten
    idle off-after 600

    # Blur behind every window's menus, not only the ones that ask
    blur menus on
    # Behind the shell's glass (lens off): wide, grained, saturated like the wm's
    blur passes 5 offset 3 noise 0.03 saturation 1.4

    # rio --app-id float
    window app=float float size 800x500
  '';

  # What the scenes need that is generated: linked into the working tree as
  # pleamar/gen (ignored by git), where the scenes include it from.
  # The agent's cursor: the user's own (the theme's `default`, every frame),
  # tinted blue, as a sheet the window manager scene draws.
  agentCursor =
    let
      cursor = config.home.pointerCursor;
    in
    pkgs.runCommand "pleamar-agent-cursor"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.imagemagick
        ];
      }
      ''
        mkdir -p $out
        python3 ${./pleamar/agent-cursor.py} ${cursor.package}/share/icons/${cursor.name}/cursors/default \
          ${toString (cursor.size * 3 / 2)} ${toString cursor.size} $out
        magick -size $(cat $out/agent-cursor.size) -depth 8 rgba:$out/agent-cursor.rgba \
          -fill '#${palette.blue}' -colorize 40% $out/agent-cursor.png
        rm $out/agent-cursor.rgba $out/agent-cursor.size
      '';

  generated = pkgs.linkFarm "pleamar-generated" {
    "agent-cursor.plm" = "${agentCursor}/agent-cursor.plm";
    "agent-cursor.png" = "${agentCursor}/agent-cursor.png";
    "theme.plm" = pkgs.writeText "theme.plm" (import ./pleamar/theme.nix { inherit lib palette; });
    "keybinds.luau" = pkgs.writeText "keybinds.luau" keybindsLuau;
  };
  tree = "/etc/nixos/home/graphical/pleamar";

  autostart = ''
    pleamar-wm --scene ${config.xdg.configHome}/pleamar/shells/desk/desk.plm --no-hud
    wm: ${lib.getExe pkgs.swayidle} -w timeout 300 'idle-dim dim' resume 'idle-dim restore'
    wm: wl-paste --type text --watch cliphist store
    wm: wl-paste --type image --watch cliphist store
    wm: /run/current-system/sw/bin/tailscale systray
    wm: ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
  '';
in
{
  home.packages = [
    pkgs.libinput
    wallpaper
    shotWindow
    shotRegion
    pkgs.grim
  ];

  xdg.configFile = {
    # symlinked out of the store, like quickshell, so pleamar reloads edits to
    # the working tree as they are saved
    "pleamar/wm".source = config.lib.file.mkOutOfStoreSymlink "${tree}/wm";
    "pleamar/shells/desk".source = config.lib.file.mkOutOfStoreSymlink "${tree}/shell";
    "pleamar/keys.conf".text = keysConf;
    "pleamar/session.conf".text = sessionConf;
    "pleamar/autostart".text = autostart;
    # pleamar-wm's session reads this before starting
    "uwsm/env-pleamar".text = ''
      export XCURSOR_THEME=${config.home.pointerCursor.name}
      export XCURSOR_SIZE=${toString config.home.pointerCursor.size}
      export NIXOS_OZONE_WL=1
    '';
  };

  # Teaches Claude Code to write and check pleamar scenes. pleamar rewrites
  # its skill files on version changes, so they are written, not linked.
  home.activation.pleamarGenerated = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ln -sfnT ${generated} ${tree}/gen
  '';

  home.activation.pleamarSkill =lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${lib.getExe pkgs.pleamar-wm} --install-skill
  '';
}
