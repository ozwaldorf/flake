#!/bin/bash
# {
	# function handle {
		# case "$1" in
			# "createworkspace>>special")
				# echo '{text": "."}'
				# ;;
			# "destroyworkspace>>special")
				# echo '{}'
				# ;;
		# esac
	# }
# 
	# /usr/bin/socat - UNIX-CONNECT:/tmp/hypr/$(echo $HYPRLAND_INSTANCE_SIGNATURE)/.socket2.sock | while read line; do handle $line; done
# } 2>&1 | tee ~/special.log

while true; do
    count=`hyprctl workspaces -j | jq '.[] | select(.name == "special:scratchpad") | .windows'`
    if [[ ! -z "$count" ]]; then
        echo '{"tooltip": "'$count'","text": "."}"'
    else
        echo '{}'
    fi
    sleep 1
done
