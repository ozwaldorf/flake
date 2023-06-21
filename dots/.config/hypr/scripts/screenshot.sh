#!/bin/bash
CHOICE=`wofi --dmenu --width 100 --height 185 -p 'Screenshot' << EOF
Fullscreen
Region
Window`

case $CHOICE in
  Fullscreen)
    hyprshot -m output --clipboard-only
	  ;;
  Region)
    hyprshot -m region --clipboard-only
	  ;;
  Window)
    hyprshot -m window --clipboard-only
	  ;;
esac
