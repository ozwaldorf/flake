#!/usr/bin/env bash

## rofi-screenshot
## Author: ceuk @ github
## Licence: WTFPL
## Usage: 
##    show the menu with rofi-screenshot
##    stop recording with rofi-screenshot -s

# Screenshot directory
screenshot_directory="$HOME/Pictures/Screenshots"

# set ffmpeg defaults
ffmpeg() {
    command ffmpeg -hide_banner -loglevel error -nostdin "$@"
}

video_to_gif() {
    ffmpeg -i "$1" -vf palettegen -f image2 -c:v png - |
    ffmpeg -i "$1" -i - -filter_complex paletteuse "$2"
}

countdown() {
  notify-send --app-name="screenshot" "Screenshot" "Recording in 3" -t 1000
  sleep 1
  notify-send --app-name="screenshot" "Screenshot" "Recording in 2" -t 1000
  sleep 1
  notify-send --app-name="screenshot" "Screenshot" "Recording in 1" -t 1000
  sleep 1
}

crtc() {
  notify-send --app-name="screenshot" "Screenshot" "Select a region to capture"
  ffcast -q "$(slop -n -f '-g %g ')" png /tmp/screenshot_clip.png
  xclip -selection clipboard -t image/png /tmp/screenshot_clip.png
  rm /tmp/screenshot_clip.png
  notify-send --app-name="screenshot" "Screenshot" "Region copied to Clipboard"
}

crtf() {
  notify-send --app-name="screenshot" "Screenshot" "Select a region to capture"
  dt=$(date '+%d-%m-%Y %H:%M:%S')
  ffcast -q "$(slop -n -f '-g %g ')" png "$screenshot_directory/$dt.png"
  notify-send --app-name="screenshot" "Screenshot" "Region saved to ${screenshot_directory//${HOME}/~}"
}

cstc() {
  ffcast -q png /tmp/screenshot_clip.png
  xclip -selection clipboard -t image/png /tmp/screenshot_clip.png
  rm /tmp/screenshot_clip.png
  notify-send --app-name="screenshot" "Screenshot" "Screenshot copied to Clipboard"
}

cstf() {
  dt=$(date '+%d-%m-%Y %H:%M:%S')
  ffcast -q png "$screenshot_directory/$dt.png"
  notify-send --app-name="screenshot" "Screenshot" "Saved to ${screenshot_directory//${HOME}/~}"
}

rgrtf() {
  notify-send --app-name="screenshot" "Screenshot" "Select a region to record"
  dt=$(date '+%d-%m-%Y %H:%M:%S')
  ffcast -q "$(slop -n -f '-g %g ' && countdown)" rec /tmp/screenshot_gif.mp4
  notify-send --app-name="screenshot" "Screenshot" "Converting to gif… (can take a while)"
  video_to_gif /tmp/screenshot_gif.mp4 "$screenshot_directory/$dt.gif"
  rm /tmp/screenshot_gif.mp4
  notify-send --app-name="screenshot" "Screenshot" "Saved to ${screenshot_directory//${HOME}/~}"
}

rgstf() {
  countdown
  dt=$(date '+%d-%m-%Y %H:%M:%S')
  ffcast -q rec /tmp/screenshot_gif.mp4
  notify-send --app-name="screenshot" "Screenshot" "Converting to gif… (can take a while)"
  video_to_gif /tmp/screenshot_gif.mp4 "$screenshot_directory/$dt.gif"
  rm /tmp/screenshot_gif.mp4
  notify-send --app-name="screenshot" "Screenshot" "Saved to ${screenshot_directory//${HOME}/~}"
}

rvrtf() {
  notify-send --app-name="screenshot" "Screenshot" "Select a region to record"
  dt=$(date '+%d-%m-%Y %H:%M:%S')
  ffcast -q "$(slop -n -f '-g %g ' && countdown)" rec "$screenshot_directory/$dt.mp4"
  notify-send --app-name="screenshot" "Screenshot" "Saved to ${screenshot_directory//${HOME}/~}"
}

rvstf() {
  countdown
  dt=$(date '+%d-%m-%Y %H:%M:%S')
  ffcast -q rec "$screenshot_directory/$dt.mp4"
  notify-send --app-name="screenshot" "Screenshot" "Saved to ${screenshot_directory//${HOME}/~}"
}

get_options() {
  echo "  Region  Clip"
  echo "  Region  File"
  echo "  Screen  Clip"
  echo "  Screen  File"
}

check_deps() {
  if ! hash "$1" 2>/dev/null; then
    echo "Error: This script requires $1"
    exit 1
  fi
}

main() {
  # check dependencies
  check_deps slop
  check_deps ffcast
  check_deps ffmpeg
  check_deps xclip
  check_deps rofi

  # Get choice from rofi
  choice=$( (get_options) | rofi -dmenu -i -fuzzy -p "Screenshot" )

  # If user has not picked anything, exit
  if [[ -z "${choice// }" ]]; then
      exit 1
  fi

  # run the selected command
  case $choice in
    '  Region  Clip')
      crtc
      ;;
    '  Screen  Clip')
      cstc
      ;;
    '  Region  File')
      crtf
      ;;
    '  Screen  File')
      cstf
      ;;
  esac

  # done
  set -e
}

main $1 &

exit 0

! /bin/bash
