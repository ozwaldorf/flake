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
    runtimeInputs = [
      pkgs.systemd
      pkgs.quickshell
    ];
    text = ''
      state="''${XDG_RUNTIME_DIR:-/tmp}/idle-dim.state"

      # The veil is a surface the shell owns, so it is only there while the
      # shell is running; dimming still works on its own if it is not. Reported
      # rather than swallowed outright: a call that never lands is a renamed
      # handler as easily as an absent shell, and silence hides the difference.
      veil() {
        qs ipc call veil "$1" >/dev/null 2>&1 ||
          printf 'idle-dim: veil %s did not reach the shell\n' "$1" >&2
      }

      # DDC writes NAK often enough that a single failure is not a real one, so
      # retry before giving up. A device that stays unreachable must not take
      # the other panels down with it, hence the non-fatal return.
      set_level() {
        for _ in 1 2 3; do
          if busctl --system call org.freedesktop.login1 \
            /org/freedesktop/login1/session/auto \
            org.freedesktop.login1.Session \
            SetBrightness ssu backlight "$1" "$2" >/dev/null 2>&1; then
            return 0
          fi
          sleep 0.3
        done
        printf 'idle-dim: %s did not take level %s\n' "$1" "$2" >&2
        return 0
      }

      case "''${1:-}" in
        dim)
          # Already dimmed: a second notification must not record the dimmed
          # level as the one to come back to.
          [ -e "$state" ] && exit 0

          # Raised before the backlight walks down: the ramp is the warning
          # that the blank is coming, and the DDC writes below are slow enough
          # to swallow it if it went last.
          veil raise

          : > "$state"
          for d in /sys/class/backlight/*; do
            [ -e "$d/max_brightness" ] || continue
            b="''${d##*/}"
            # ddcci panels expose no actual_brightness, only the level last
            # asked for, so brightness is the reading that is always there.
            cur=$(cat "$d/actual_brightness" 2>/dev/null || cat "$d/brightness")
            max=$(cat "$d/max_brightness")
            printf '%s %s\n' "$b" "$cur" >> "$state"

            # a tenth of the panel's range, and never up from where it was
            target=$(( max / 10 ))
            [ "$target" -lt "$cur" ] || target="$cur"
            set_level "$b" "$target"
          done
          ;;

        restore)
          # Dropped first and unconditionally: a veil left up over a session
          # that never recorded a level would have nothing else to take it
          # down, and the screen would stay blurred.
          veil lower

          [ -e "$state" ] || exit 0
          # Drop the state first: a panel that refuses its level must not leave
          # a file behind that makes the next dim think it already ran.
          levels=$(cat "$state")
          rm -f "$state"
          printf '%s\n' "$levels" | while read -r b level; do
            [ -n "$b" ] || continue
            set_level "$b" "$level"
          done
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
