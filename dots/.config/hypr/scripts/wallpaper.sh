#!/bin/bash
# Writes some splash text onto images from ~/.config/hypr/wallpapers
# USAGE:
# 	random: ./wallpaper.sh
#   specific: ./wallpaper.sh file.png
#

cd ~/.config/hypr/wallpapers

if [[ -z "$1" ]]; then
	# default use random
	original=`/bin/ls | sed -n "$((RANDOM%$(/bin/ls | wc -l)+1))p"`
else
	original="$1"
fi

convert $original \
	-font "Jetbrains-Mono-Light-Nerd-Font-Complete" \
	-fill white -gravity South -pointsize 20 \
	-annotate +0+0 "$(hyprctl splash)" .splashed.jpg

# restart wallpaper
pkill hyprpaper
hyprpaper
