#!/bin/bash

[[ -z $GITHUB_TOKEN ]] && GITHUB_TOKEN=$GH_TOKEN

curlArgs=(
	-s
	-H "Accept: application/vnd.github+json"
	-H "Authorization: Bearer $GITHUB_TOKEN"
	-H "X-GitHub-Api-Version: 2022-11-28"
)

rofiTheme=\
'#listview { columns: 1; }
#element-text { font: "FiraCode Nerd Font 14\"; }
#element-icon { size: 0; }'

json=$(curl -s "${curlArgs[@]}" 'https://api.github.com/notifications?all=true')

choice=$(jq -r '
	.[] |
	"\(if (.unread) then "*" else "  " end) \(.updated_at |
	strptime("%Y-%m-%dT%H:%M:%SZ") |
	mktime |
	strftime("%h %d %k:%M")) \(.repository.full_name) | \(.subject.title)"
	' <<<$json \
  	| rofi -theme-str "$rofiTheme" -theme ~/.config/rofi/github.rasi -dmenu -p "Github" \
  	| sed -E 's/^.* \| //g')

[[ -z $choice ]] && exit 1

item=$(jq -r "
	.[] |
	select(.subject.title==\"$choice\") |
	{id: .id, url: .subject.url}"<<<$json)

# mark as read
id=$(jq -r .id<<<$item)
curl "${curlArgs[@]}" https://api.github.com/notifications/threads/$id &>/dev/null &

# get url and open in browser
url=$(curl "${curlArgs[@]}" $(jq -r .url<<<$item) | jq -r .html_url)
$BROWSER $url
