#!/bin/bash
# Usage: capture.sh fr|en
# The app must already run signed in as <lang>-main (see run.sh). Routes come from
# .ids.json (written by seed.mjs); raw captures land in raw/<lang>-<shot>.png.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LANG_CODE=${1:?usage: capture.sh fr|en}
UDID=$("$HERE/simulator.sh" udid)
ROUTE_FILE="$HERE/.route.txt"
WAIT=${SHOT_WAIT:-6}
mkdir -p "$HERE/raw"

route() { node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))[process.argv[2]].routes[process.argv[3]])" "$HERE/.ids.json" "$LANG_CODE" "$1"; }

for shot in home wl wish friendwish booked; do
  printf "%s" "$(route "$shot")" > "$ROUTE_FILE"
  sleep "$WAIT"
  xcrun simctl io "$UDID" screenshot "$HERE/raw/$LANG_CODE-$shot.png" >/dev/null 2>&1
  echo "shot $LANG_CODE-$shot"
done
