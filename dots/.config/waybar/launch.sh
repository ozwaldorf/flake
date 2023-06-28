#!/bin/bash

trap "killall waybar" EXIT

while true; do
    waybar &
    inotifywait -e create,modify,attrib -r $HOME/.config/waybar
    killall waybar
done
