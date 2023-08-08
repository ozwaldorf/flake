#!/bin/bash
trap "killall waybar" EXIT # ensure waybar is killed with the script
while true; do
    waybar &
    inotifywait -e create,modify,attrib -r "$HOME/.config/waybar"
    killall waybar
done
