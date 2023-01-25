#!/usr/bin/env bash

script="$HOME/.config/scripts/styles.sh"

# Launch Rofi
MENU="$(rofi -no-config -no-lazy-grab -sep "|" -dmenu -i -p '' \
-theme ~/.config/rofi/styles.rasi \
<<< " Dracula| Black| Adapta| Dark| Red| Green| Teal| Gruvbox| Nord| Solarized| Cherry|")"
            case "$MENU" in
				*Dracula) "$script" --mode0 ;;
				*Black) "$script" --mode1 ;;
				*Adapta) "$script" --mode2 ;;
				*Dark) "$script" --mode3 ;;
				*Red) "$script" --mode4 ;;
				*Green) "$script" --mode5 ;;
				*Teal) "$script" --mode6 ;;
				*Gruvbox) "$script" --mode7 ;;
				*Nord) "$script" --mode8 ;;
				*Solarized) "$script" --mode9 ;;
				*Cherry) "$script" --mode10 ;;
            esac
