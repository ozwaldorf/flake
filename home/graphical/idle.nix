{ pkgs, ... }:
let
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
  #
  # Blanking is a hyprland dispatcher and takes its lua form here; the bare
  # "dpms off" spelling is not accepted.
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
in
{
  home.packages = [ idleDim ];

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
}
