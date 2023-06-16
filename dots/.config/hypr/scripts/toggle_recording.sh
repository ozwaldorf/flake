#!/bin/bash 
if [[ -f "/tmp/recording" ]]; then
  rm /tmp/recording
  pkill wf-recorder -SIGINT
  wl-copy < /tmp/recording.mp4
else
  touch /tmp/recording
  wf-recorder -t -f /tmp/recording.mp4 &
fi
