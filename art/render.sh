#!/bin/sh
# Renders art/icon.html and art/thumbnail.html to PNG with headless Chrome.
# Run from the repo root: python3 art/make_art.py && art/render.sh
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

render() {
	"$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
		--virtual-time-budget=8000 --window-size="$2" --screenshot="$PWD/$3" "file://$PWD/$1" 2>/dev/null
	echo "rendered $3"
}

render icon.html 512,512 icon.png
for page in thumbnail*.html; do
	render "$page" 1920,1080 "${page%.html}.png"
done
