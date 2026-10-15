#!/bin/bash
# Usage: render.sh
# Renders the store visuals from raw/<lang>-*.png with headless Chrome:
#   out/apple-6.9in/<lang>/0N.png                  1320x2868
#   out/google-play/<lang>/0N.png                  1080x1920
#   out/google-play/<lang>/feature-graphic.png     1024x500
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
[[ -x "$CHROME" ]] || { echo "Chrome not found, set CHROME=/path/to/chrome" >&2; exit 1; }

render() { # <url> <width> <height> <out>
  mkdir -p "$(dirname "$4")"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=3000 \
    --window-size="$2,$3" --screenshot="$4" "$1" >/dev/null 2>&1
  [[ -s "$4" ]] || { echo "failed: $4" >&2; exit 1; }
  echo "$4"
}

for lang in fr en; do
  for n in 1 2 3 4; do
    url="file://$HERE/compose/shot.html?lang=$lang&n=$n"
    render "$url" 1320 2868 "$HERE/out/apple-6.9in/$lang/0$n.png"
    render "$url" 1080 1920 "$HERE/out/google-play/$lang/0$n.png"
  done
  render "file://$HERE/compose/feature.html?lang=$lang" 1024 500 "$HERE/out/google-play/$lang/feature-graphic.png"
done
