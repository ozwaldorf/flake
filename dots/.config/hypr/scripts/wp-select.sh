#!/bin/bash
if [[ -z $DMENU ]]; then
  DMENU="wofi -d --location center"
fi

SCRIPT_NAME=$(basename $0)
WALLPAPER_DIR="$HOME/.wallpapers"
LUTGEN_THEME="catppuccin-mocha"

wp_unsplash () {
  if [[ -z $1 ]]; then
    QUERY="wallpaper"
  else QUERY="$1"; fi

  #RES=`hyprctl monitors -j | jq -r 'first | "\(.width)x\(.height)"'`
  RES='3840x2160'
  
  curl -Ls "https://source.unsplash.com/random/$RES/?$QUERY" -o /tmp/wallpaper.jpg
  wp_lutgen /tmp/wallpaper.jpg $WALLPAPER_DIR/ctp-unsplash.png 
}

wp_lutgen () {
  lutgen apply -cl16 -p $LUTGEN_THEME $1 -o $2
  wp_file $2
}

wp_restore () {
  swww img `cat $WALLPAPER_DIR/.current`
}

wp_random () {
  wp_file `ls | shuf -n 1`
}

wp_file () {
  path=`realpath $1`
  echo "$path" > $WALLPAPER_DIR/.current
  cp $1 /usr/share/sddm/themes/chili-git/assets/background.png
  swww img --transition-type any "$1"
}

wp_save () {
  cp `cat $WALLPAPER_DIR/.current` $1
}

wp_dmenu () {
  cd $WALLPAPER_DIR
  # select subcommand
  choices=("Unsplash" "Select File" "Random File" "Save Current" "Catppuccinify")
  choice=`printf '%s\n' "${choices[@]}" | $DMENU`

  case $choice in
    "${choices[0]}")
      wp_unsplash > .log
      ;;
    "${choices[1]}")
      wp_file `ls | $DMENU`
      ;;
    "${choices[2]}")
      wp_random
      ;;
    "${choices[3]}")
      current=`cat .current`
      wp_save `ls | $DMENU --search $current`
      ;;
    "${choices[4]}")
      file=`(echo "current"; ls) | $DMENU`
      echo "$file"
      if [[ "$file" -eq "current" ]]; then
        file=`cat .current`
      fi
      wp_lutgen $file ".lutgen.png"
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
  unsplash [QUERY] Generate a random catppuccin wallpaper from Unsplash
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
