#!/usr/bin/env bash
# Fetches one random landscape photograph from Wikimedia Commons and prints the
# path it was saved to. Prints nothing and exits non zero if nothing suitable
# was found, which the caller treats as "keep what is up".
#
# No grading happens here: the shell grades through a CLUT at draw time, so what
# lands on disk is the original file.
set -euo pipefail

DIR="${WALLPAPER_DIR:-$HOME/Pictures/walls/commons}"
# Commons asks that clients identify themselves with a contact address, and
# throttles anonymous traffic that does not.
UA="quickshell-wallpaper/1.0 (https://github.com/ozwaldorf/nixos; whisper@mirageprivacy.com)"
API="https://commons.wikimedia.org/w/api.php"

# Quality images is a flat category of ~460k community reviewed photographs.
# deepcat walks into the landscape subtree, which incategory alone cannot do:
# Commons files sit in narrow leaf categories, so a shallow match finds almost
# nothing. deepcat caps how many subcategories it will apply and says so in a
# warning, which is fine here, the result is a large stable pool rather than an
# exhaustive one.
POOL='incategory:"Quality images" deepcat:"Landscapes" filetype:bitmap filew:>3840'

# Wide enough to fill the widest output without upscaling. Commons only renders
# thumbnails at standard widths, so the API's own thumburl is used verbatim
# rather than built by hand, which 400s.
WIDTH="${WALLPAPER_WIDTH:-3840}"

# Panoramas pass a width filter and then crop to a letterboxed strip on a normal
# display, so the ratio is bounded at both ends. There is no aspect ratio search
# keyword, so this is filtered here from the returned dimensions.
MIN_AR="${WALLPAPER_MIN_AR:-1.4}"
MAX_AR="${WALLPAPER_MAX_AR:-2.1}"

mkdir -p "$DIR"

# gsrsort=random is the only ordering that can be combined with a filtered
# search. The random generator proper ignores categories entirely and returns
# whatever is in the file namespace, including PDFs and diagrams.
#
# Twenty candidates per call so the ratio filter below usually has something
# left; a single pick would fail often enough to be noticeable.
#
# extmetadata is deliberately not requested: it carries raw control characters
# that are invalid inside a JSON string and make strict parsers fail outright.
response=$(curl -sfG "$API" -A "$UA" --compressed --max-time 30 \
    -d action=query -d format=json -d formatversion=2 -d maxlag=5 \
    -d generator=search -d gsrnamespace=6 -d gsrlimit=20 -d gsrsort=random \
    --data-urlencode "gsrsearch=$POOL" \
    -d prop=imageinfo -d iiprop='url|size|mime' -d "iiurlwidth=$WIDTH") || exit 1

pick=$(jq -r --argjson min "$MIN_AR" --argjson max "$MAX_AR" '
    [.query.pages[]?
     | .imageinfo[0] as $i
     | select($i != null and $i.thumburl != null)
     | select(($i.width / $i.height) >= $min and ($i.width / $i.height) <= $max)
     | {url: $i.thumburl, name: (.title | sub("^File:"; ""))}]
    | first // empty
    | "\(.url)\t\(.name)"' <<<"$response")

[ -n "$pick" ] || exit 1

url=${pick%%$'\t'*}
name=${pick#*$'\t'}

# Commons titles carry spaces, slashes and quotes. Flattened to something safe
# to sit in a path, keeping the name legible so the file is identifiable.
safe=$(printf '%s' "$name" | tr -c '[:alnum:]._-' '_' | cut -c1-120)
out="$DIR/$safe"

[ -f "$out" ] && { printf '%s\n' "$out"; exit 0; }

# Downloaded beside the target and moved into place so a fetch interrupted part
# way through cannot leave a truncated image for the shell to load.
tmp=$(mktemp "$DIR/.fetch.XXXXXX")
trap 'rm -f "$tmp"' EXIT

curl -sfL -A "$UA" --max-time 120 "$url" -o "$tmp" || exit 1
[ -s "$tmp" ] || exit 1

# mktemp creates at 0600; these are ordinary pictures and inherit the usual mode
chmod 644 "$tmp"
mv "$tmp" "$out"
trap - EXIT

printf '%s\n' "$out"
