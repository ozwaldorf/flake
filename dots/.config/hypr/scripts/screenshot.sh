#!/bin/bash
CHOICE=`wofi --dmenu -p 'Screenshot' << EOF
Fullscreen
Region
Focused
EOF`

case $CHOICE in
  Fullscreen)
    hyprshot -m output --clipboard-only
	  ;;
  Region)
    hyprshot -m region --clipboard-only
	  ;;
  Focused)
    hyprshot -m focused --clipboard-only
	  ;;
  '')
    notify-send "Screenshot" "Cancelled"
    exit 0
    ;;
esac
