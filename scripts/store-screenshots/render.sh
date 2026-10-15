#!/bin/bash
# Usage: render.sh
# Renders the store visuals from raw/<lang>-*.png with headless Chrome:
#   out/apple-6.9in/<lang>/0N.png                  1320x2868
#   out/google-play/<lang>/0N.png                  1080x1920
#   out/google-play/<lang>/feature-graphic.png     1024x500
#   out/apple-creative/<lang>/header.png           3840x1646 (product page header)
#   out/apple-creative/<lang>/search-results.png   3840x2560
#   out/apple-creative/<lang>/universal.png        5244x2950
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
  creative="file://$HERE/compose/creative.html?lang=$lang"
  render "$creative&type=header" 3840 1646 "$HERE/out/apple-creative/$lang/header.png"
  render "$creative&type=search" 3840 2560 "$HERE/out/apple-creative/$lang/search-results.png"
  render "$creative&type=universal" 5244 2950 "$HERE/out/apple-creative/$lang/universal.png"
done
