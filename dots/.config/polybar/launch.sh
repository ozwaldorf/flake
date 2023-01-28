#!/usr/bin/env bash

# Add this script to your wm startup file.

CONFIG="$HOME/.config/polybar/config.ini"

# source ~/.env for GITHUB_TOKEN
source "$HOME/.env"

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch the bar
polybar -q bottom -c "$CONFIG" &
polybar -q top -c "$CONFIG" &
