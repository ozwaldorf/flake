#!/bin/bash
if [[ -z $DMENU ]]; then
  DMENU="wofi -d --location center --height 240 --width 100"
fi

SCRIPT_NAME=$(basename $0)
WALLPAPER_DIR="$HOME/Pictures"

wp_picsum () {
  #RES="$(hyprctl monitors -j | jq -r 'first | "\(.width)x\(.height)"')"

  curl -L "https://picsum.photos/3840/2160.jpg" -o /tmp/wallpaper.jpg
  wp_lutgen /tmp/wallpaper.jpg $WALLPAPER_DIR/picsum.png 
}

wp_lutgen () {
  lutgen apply -cl16 $1 -o $2 -p carburetor --lum 0.1 --preserve
  wp_file "$2"
}

wp_restore () {
  swww img "$(cat "$WALLPAPER_DIR/.current")"
}

wp_random () {
  wp_file "$(ls | shuf -n 1)"
}

wp_file () {
  path="$(realpath "$1")"
  echo "$path" > "$WALLPAPER_DIR/.current"
  cp $1 /usr/share/sddm/themes/chili/assets/background.png
  swww img --transition-type any "$1"
}

wp_save () {
  cp "$(cat $WALLPAPER_DIR/.current)" $1
}

wp_dmenu () {
  cd "$WALLPAPER_DIR" || exit 1
  # select subcommand
  choices=("Picsum" "Select File" "Random File" "Save Current")
  choice="$(printf '%s\n' "${choices[@]}" | $DMENU)"

  case $choice in
    "${choices[0]}")
      wp_picsum > .log
      ;;
    "${choices[1]}")
      wp_file "$(zenity --file-selection --file-filter='Images | *.png *.jpg *.jpeg')"
      ;;
    "${choices[2]}")
      wp_random
      ;;
    "${choices[3]}")
      current="$(cat .current)"
      wp_save "$(ls | $DMENU --search "$current")"
      ;;
    *)
      exit 1
      ;;
  esac
}

wp_help () {
cat << EOF
Usage: $SCRIPT_NAME <SUBCOMMAND>

Subcommands:
  dmenu            Interactive mode with dmenu
  restore          Restores previous wallpaper
  picsum [QUERY] Generate a random catppuccin wallpaper from Unsplash
  lutgen <PATH>    Theme an existing wallpaper using lutgen
  random           Picks a random wallpaper in $WALLPAPER_DIR
  file <PATH>      Set the wallpaper to a file
  save <NAME>      Save the current wallpaper to a new name. Must include extension
EOF
}

subcommand=$1
case $subcommand in
  "" | "-h" | "--help")
    wp_help
    ;;
  *)
    shift
    wp_${subcommand} $@
    if [ $? = 127 ]; then
      wp_help >&2
      exit 1
    fi
    ;;
esac
