#!/bin/bash
i=1 

export colors="rgba(F48FB1FF) rgba(A1EFD3FF) rgba(F1FA8CFF) rgba(92B6F4FF) rgba(BD99FFFF) rgba(87DFEBFF)"

while [[ $i -gt 0 ]]; do
  if [[ $i -lt 360 ]]; then 
    hyprctl keyword general:col.active_border "$colors $((i))deg" >/dev/null
    sleep 0.01
    i=$((i+1))
  else 
    hyprctl keyword general:col.active_border "$colors $((i))deg" >/dev/null
    sleep 0.01
    i=1
  fi
done
