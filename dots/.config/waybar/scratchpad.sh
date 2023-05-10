#!/bin/bash

function handle {
	case "$1" in
		"createworkspace>>special:scratchpad")
			echo '{"tooltip": "'$count'","text": "."}'
			;;
		"destroyworkspace>>special:scratchpad")
			echo '{}'
			;;
	esac
}

/usr/bin/socat - UNIX-CONNECT:/tmp/hypr/$(echo $HYPRLAND_INSTANCE_SIGNATURE)/.socket2.sock | while read line; do handle $line; done
