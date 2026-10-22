#!/usr/bin/env bash
# A tour of the desktop: seven windows opened from the keys and the launcher
# and tiled into rows, the overview, windows moved and resized, then the
# drawer page by page.
# It runs in a screenless pleamar-wm of its own, with the user's wm and shell
# scenes, driven by its own pointer and keyboard as a person would, the keys
# shown on screen, and recorded with wf-recorder.
#
#   demo.sh [-o VIDEO]    PLEAMAR_WM: the pleamar-wm the session runs (a build to try)
set -euo pipefail

OUT=$PWD/demo.mp4
while getopts "o:" o; do
    case $o in
        o) OUT=$(realpath -m "$OPTARG") ;;
        *) exit 1 ;;
    esac
done

desk() { pleamar-wm --say desk "$@"; }
pause() { sleep "${1:-1.2}"; }

# The session's own keyboard and pointer: a line each on its input pipe,
# untimed. Kept open on fd 3: opened for each, lines got lost between them.
line() { echo "$1" >&3; }

# What is pressed, for the keys shown on screen.
ksn=0
show() {
    ksn=$((ksn + 1))
    desk "text ks.feed $ksn $*" >/dev/null 2>&1 || true
}

# A key or chord as the session takes it (keysym names and evdev code), and
# as it is shown.
press() {
    line "key:$2"
    show key "$1"
}

# The beat between keys, uneven as a person's, with a hesitation now and then.
keygap() {
    local ms=$((25 + RANDOM % 65))
    ((RANDOM % 12 == 0)) && ms=$((ms + 100 + RANDOM % 200))
    sleep "$(printf '0.%03d' "$ms")"
}

# The keys typed: evdev code, and keysym where it is not the character.
declare -A CODE=(
    [q]=16 [w]=17 [e]=18 [r]=19 [t]=20 [y]=21 [u]=22 [i]=23 [o]=24 [p]=25
    [a]=30 [s]=31 [d]=32 [f]=33 [g]=34 [h]=35 [j]=36 [k]=37 [l]=38
    [z]=44 [x]=45 [c]=46 [v]=47 [b]=48 [n]=49 [m]=50
    [1]=2 [2]=3 [3]=4 [4]=5 [5]=6 [6]=7 [7]=8 [8]=9 [9]=10 [0]=11
    [' ']=57 [-]=12 [,]=51 [.]=52 [/]=53
)
declare -A SYM=([' ']=space [-]=minus [,]=comma [.]=period [/]=slash)

# One character, with Shift for capitals and the shifted ones used here.
typech() {
    local c=$1 k=$1 up=false
    case $c in
        [A-Z]) k=${c,,} up=true ;;
        '*') k=8 up=true ;;
    esac
    $up && line "keydown:Shift_L:42"
    line "key:${SYM[$k]:-$k}:${CODE[$k]}"
    $up && line "keyup:Shift_L:42"
    if [ "$c" = " " ]; then show space; else show type "$c"; fi
}

# Text typed into whatever has the keyboard, a key at a time.
typetext() {
    local i
    for ((i = 0; i < ${#1}; i++)); do
        typech "${1:i:1}"
        keygap
    done
}

# The pointer, gliding from where it is, eased. It starts on the rail, off
# the windows: focus follows it, and a new window joins the row of the one
# with the keyboard.
px=20
py=540
glide() {
    local i n=16 t
    for ((i = 1; i <= n; i++)); do
        t=$((1000 - (1000 - 1000 * i / n) * (1000 - 1000 * i / n) / 1000))
        line "$((px + ($1 - px) * t / 1000)),$((py + ($2 - py) * t / 1000))"
        sleep 0.014
    done
    px=$1 py=$2
}

click() {
    line down
    sleep 0.06
    line up
    show click "Left click"
}

# Every window by its name and program.
names() { pleamar-wm agent windows | awk '{ print $1, $2 }' | sort; }

# A window's box, as shown now (smaller in the overview): x y w h.
box() {
    pleamar-wm agent windows | awk -v w="$1" '$1 == w {
        for (i = 1; i <= NF; i++) if ($(i + 1) == "at") {
            split($i, s, "x"); split($(i + 2), p, ",")
            print p[1], p[2], s[1], s[2]; exit
        }
    }'
}

focused() { pleamar-wm agent windows | grep -q "^ *$1 .*has the keyboard"; }

# The corner handle of the window with the keyboard that is on screen and
# nearest its middle, as the wm has it: x y of its middle, and which sides it
# moves (-1 the left or top, 1 the right or bottom).
corner() {
    local n
    n=$(pleamar-wm --say wm "get win.focus") || return 1
    pleamar-wm --say wm describe | awk -v n="$n" '$2 ~ "^rsz\\.[4-7]\\." n "$" && $3 == "at" {
        split($4, p, ","); x = p[1] + 8; y = p[2] + 8
        if (x < 0 || y < 0 || x > 1920 || y > 1080) next
        d = (x - 960) ^ 2 + (y - 540) ^ 2
        if (!b || d < bd) { b = 1; bd = d; e = substr($2, 5, 1); bx = x; by = y }
    } END { if (b) print bx, by, (e == 5 || e == 7 ? 1 : -1), (e >= 6 ? 1 : -1) }'
}

# The window with the keyboard stretched by that corner with the pointer,
# grown by dx, dy (shrunk below 0): its width, and its row's height.
stretch() {
    local x y sx sy i a b='' _
    # its corner once the rows have stopped moving
    for _ in $(seq 30); do
        a=$(corner)
        [ -n "$a" ] && [ "$a" = "$b" ] && break
        b=$a
        sleep 0.15
    done
    read -r x y sx sy <<<"$a" || return 0
    glide "$x" "$y"
    pause 0.2
    line down
    show click "Left drag"
    for ((i = 1; i <= 24; i++)); do
        line "$((px + sx * $1 * i / 24)),$((py + sy * $2 * i / 24))"
        sleep 0.02
    done
    px=$((px + sx * $1)) py=$((py + sy * $2))
    pause 0.1
    line up
}

# The window next to another the way given (Up, Down, Left, Right): the
# nearest whose middle is more that way than across from it.
toward() {
    pleamar-wm agent windows | awk -v w="$1" -v d="$2" '{
        for (i = 1; i <= NF; i++) if ($(i + 1) == "at") {
            split($i, s, "x"); split($(i + 2), p, ",")
            n++; id[n] = $1; mx[n] = p[1] + s[1] / 2; my[n] = p[2] + s[2] / 2
            if ($1 == w) me = n
        }
    } END {
        for (j = 1; j <= n; j++) {
            dx = mx[j] - mx[me]; dy = my[j] - my[me]
            a = d == "Up" ? -dy : d == "Down" ? dy : d == "Left" ? -dx : dx
            b = d == "Up" || d == "Down" ? dx : dy
            if (j == me || a <= (b < 0 ? -b : b)) continue
            if (!best || a * a + b * b < bd) { best = j; bd = a * a + b * b }
        }
        if (best) print id[best]
    }'
}
# A window and a way it can be carried, at random, other than the one given:
# into the bottom row with "last".
shuffle() {
    local w d t ws
    mapfile -t ws < <(names | awk '{ print $1 }' | shuf)
    for w in "${ws[@]}"; do
        [ "$w" = "$1" ] && continue
        for d in $(shuf -e Up Down Left Right); do
            t=$(toward "$w" "$d")
            [ -n "$t" ] || continue
            if [ "${2:-}" = last ]; then
                [ "$d" = Down ] && [ -z "$(toward "$t" Down)" ] || continue
            fi
            echo "$w $d"
            return 0
        done
    done
}

# A window carried with Super held onto the one next to it the way given,
# and let go there: the two trade places.
carry() {
    local t x y w h
    t=$(toward "$1" "$2")
    [ -n "$t" ] || return 0
    read -r x y w h < <(box "$1") || return 0
    line "keydown:Super_L:125"
    glide $((x + w / 2)) $((y + h / 2))
    pause 0.1
    line down
    show click "Super + Left drag"
    read -r x y w h < <(box "$t") || true
    glide $((x + w / 2)) $((y + h / 2))
    pause 0.15
    line up
    line "keyup:Super_L:125"
}

# A window picked with the pointer: on its title bar, or its middle.
pick() {
    local x y w h
    read -r x y w h < <(box "$1") || return 0
    if [ "${2:-}" = middle ]; then glide $((x + w / 2)) $((y + h / 2)); else glide $((x + w / 2)) $((y + 12)); fi
    pause 0.1
    click
}

# Waits for the window of what was just started (names before it given, and
# its program, as a pattern, while another may be opening meanwhile), kept in
# wins and named in win. A new window takes the keyboard and joins the row of
# the one that had it: 1, 2, 2+1, 2+2, 2+3, then 2+3+1 and 2+3+2.
wins=()
win=
newwin() {
    local _
    win=
    for _ in $(seq 200); do
        win=$(comm -13 <(echo "$1") <(names) | awk -v p="$2" '$2 ~ p { print $1; exit }')
        [ -n "$win" ] && break
        sleep 0.1
    done
    [ -n "$win" ] || return 0
    wins+=("$win")
    # and has the keyboard and its place, so the next joins its row
    for _ in $(seq 30); do
        focused "$win" && [ "$(pleamar-wm --say wm "get nw")" = -1 ] && break
        sleep 0.1
    done
    return 0
}

# An app started from the launcher (Super+D) by what is typed there.
launch() {
    press "Super + D" Super+d:32
    pause 0.15
    typetext "$1"
    pause 0.35
    press Enter Return:28
}

# The same, waiting for its window, of that program.
app() {
    local before
    before=$(names)
    launch "$1"
    newwin "$before" "$2"
}

# Lines typed at the prompt of the window just opened, taking the keyboard
# back with the pointer if another window took it meanwhile.
run() {
    local l i
    for l; do
        for ((i = 0; i < ${#l}; i++)); do
            focused "$win" || pick "$win"
            typech "${l:i:1}"
            keygap
        done
        keygap
        press Enter Return:28
        pause 0.1
    done
}

# A terminal from Super+Return, running those lines, if any, once its shell is up.
term() {
    local before
    pause 0.4
    before=$(names)
    press "Super + Enter" Super+Return:28
    newwin "$before" rio
    [ $# -gt 0 ] || return 0
    pause 0.2
    run "$@"
}

# Sockets take short paths only, so the runtime dir is short too
rt=$(mktemp -d /tmp/pleamar-demo.XXXX)
mkfifo "$rt/input"
echo "pleamar-wm --scene $HOME/.config/pleamar/shells/desk/desk.plm --no-hud" >"$rt/autostart"
export XDG_RUNTIME_DIR=$rt WAYLAND_DISPLAY=pleamar-1
export PLEAMAR_SOCKETS=$rt/pleamar-pleamar-1 CUA_INJECT_SOCKET=$rt/pleamar-pleamar-1/cua-inject.sock
# A clipboard history of its own, for the clipboard page, not the user's
export CLIPHIST_DB_PATH=$rt/cliphist.db
for clip in "nix flake update" "https://github.com/ozwaldorf/flake" "sudo nixos-rebuild switch --flake .#" \
    "pleamar --check desk.plm" "git commit -m 'feat(wm): rows that tile into a hexagon'" "42"; do
    printf '%s' "$clip" | cliphist store
done

hpid=
rpid=
cleanup() {
    [ -n "$rpid" ] && kill -INT "$rpid" 2>/dev/null && wait "$rpid" || true
    # dbus-run-session leaves its program running when it is stopped
    [ -n "$hpid" ] && pkill -P "$hpid" && wait "$hpid" || true
    rm -rf "$rt"
}
trap cleanup EXIT

# On a bus of its own, so nothing reaches the real session's programs
(cd ~ && PLEAMAR_WM_AUTOSTART=$rt/autostart PLEAMAR_HEADLESS_INPUT_FIFO=$rt/input \
    PLEAMAR_HEADLESS_PNG=$rt/last.png exec dbus-run-session -- "${PLEAMAR_WM:-pleamar-wm}" headless) >"$rt/wm.log" 2>&1 &
hpid=$!
# The pipe only once the session listens on it, or the open waits for good
for _ in $(seq 100); do
    desk "get ptrmon" >/dev/null 2>&1 && break
    sleep 0.2
done
pause 0.5
exec 3>"$rt/input"
line "$px,$py"
# The keys on screen, told rather than read from this machine's devices
desk "fact ks.fed true" "emit ks_toggle"
pause 1
wf-recorder -y -f "$OUT" >"$rt/rec.log" 2>&1 &
rpid=$!
pause 0.3

# Seven windows into rows of two, three and two, each joining the row of the
# one before.
term "cd /etc/nixos" nvim
term
app files Nautilus
term btm
term
term ", pipes.sh"
term weechat
pause 0.2

# The overview to pick a window: out, over to another with the pointer, and
# in on it, a few times.
for w in "${wins[1]:-}" "${wins[3]:-}" "${wins[5]:-}"; do
    press "Super + Esc" Super+Escape:1
    pause 0.45
    [ -n "$w" ] && pick "$w" middle
    pause 0.2
    press Esc Escape:1
    pause 0.6
done

# The overview again, windows carried about in it at random, the last one
# into the bottom row
press "Super + Esc" Super+Escape:1
pause 0.45
w=
for i in 1 2 3 4 5 6; do
    read -r w d < <(shuffle "$w" "$( ((i == 6)) && echo last)") || break
    carry "$w" "$d"
    pause 0.45
done
press Esc Escape:1
pause 0.6

# Up close on that one: made bigger by its corner and back, then moved by
# the keys, from the bottom row: up, up, right, down, left, down
path="Up Up Right Down Left Down"
stretch 260 160
pause 0.5
stretch -260 -160
pause 0.4
declare -A ARROW=([Up]=103 [Down]=108 [Left]=105 [Right]=106)
for d in $path; do
    press "Super + Shift + $d" "Super+Shift+$d:${ARROW[$d]}"
    pause 0.45
done
pause 0.2

# The drawer, page by page, each from its key: system, apps, clipboard, keys
press "Super + Tab" Super+Tab:15
pause 1.2
press "Super + D" Super+d:32
pause 0.35
typetext '12*3.5'
pause 0.9
press "Super + Shift + D" Super+Shift+d:32
pause 1
press "Super + Shift + ?" Super+Shift+question:53
pause 1
press "Super + Shift + ?" Super+Shift+question:53
pause 0.5

# Windows closed one at a time
for _ in "${wins[@]}"; do
    press "Super + Shift + Q" Super+Shift+q:16
    pause 0.3
done
pause 0.4
echo "recorded to $OUT"
