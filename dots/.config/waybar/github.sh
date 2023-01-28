#!/bin/bash
source ~/.env
count=`curl -su username:${GITHUB_TOKEN} https://api.github.com/notifications | jq 'select(.>=[] and .<{}) | length'`
if [[ -z "$count" ]]; then
	echo "error"
	exit 1
else
	echo '{"text": "'$count'", "tooltip": "'$count' Notifications", "class": "$class"}'
fi
