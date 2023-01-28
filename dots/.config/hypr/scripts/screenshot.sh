#!/bin/bash
CHOICE=`wofi --dmenu -p 'Screenshot' << EOF
fullscreen
region
focused
EOF`

case $CHOICE in
    fullscreen)
        hyprshot -m output --clipboard-only
	;;
    region)
        hyprshot -m region "$EXPENDED_FILENAME"
	;;
    focused)
        hyprshot -m focused "$EXPENDED_FILENAME"
	;;
    '')
        notify-send "Screenshot" "Cancelled"
        exit 0
        ;;
esac
