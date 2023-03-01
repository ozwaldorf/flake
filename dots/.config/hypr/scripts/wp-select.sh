#!/bin/bash
if [[ -z $DMENU ]]; then
  DMENU="wofi -d --location center"
fi

SCRIPT_NAME=$(basename $0)
WALLPAPER_DIR="$HOME/.wallpapers"

cd $WALLPAPER_DIR

wp_unsplash () {
  if [[ -z $1 ]]; then
    QUERY="wallpaper"
  else QUERY="$1"; fi

  RES=`hyprctl monitors -j | jq -r 'first | "\(.width)x\(.height)"'`

  curl -Ls "https://source.unsplash.com/random/$RES/?$QUERY" -o /tmp/wallpaper.jpg
  wp_ctpify /tmp/wallpaper.jpg ctp-unsplash.png 
}

wp_ctpify () {
  magick $1 .mocha-hald-clut.png -hald-clut $2
  wp_file $2
}

wp_restore () {
  wp_file `cat .current`
}

wp_random () {
  wp_file `ls | shuf -n 1`
}

wp_file () {
  echo "$1" > .current
  swww img --transition-type any "./$1"
}

wp_save () {
  cp `cat .current` $1
}

wp_dmenu () {
  # select subcommand
  choice=`printf "Catppuccin Unsplash\nSelect File\nRandom File\nSave Current\nCatppuccinify" | $DMENU`

  case $choice in
    "Catppuccin Unsplash")
      wp_unsplash
      ;;
    "Select File")
      wp_file `ls | $DMENU`
      ;;
    "Random File")
      wp_random
      ;;
    "Save Current")
      current=`cat .current`
      wp_save `ls | $DMENU --search $current`
      ;;
    "Catppuccinify")
      file=`ls | $DMENU`
      wp_ctpify $file ".catppuccinify"
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
  dmenu          Interactive mode with dmenu
  restore        Restores previous wallpaper
  unsplash [RES]   Generate a random catppuccin wallpaper from picsum, with an
                  optional resolution like "1920/1080". Defaults to the first
                  monitors resolution returned by hyprctl.
  ctpify <PATH>  Generate a catppuccin wallpaper from a file
  random         Picks a random wallpaper in $WALLPAPER_DIR
  file <PATH>    Set the wallpaper to a file
  save <NAME>    Save the current wallpaper to a new name. Must include extension
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
