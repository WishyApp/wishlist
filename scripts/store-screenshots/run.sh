#!/bin/bash
# Usage: [SHOTS_DEVICE=iphone|ipad] run.sh <account-key>   (e.g. fr-main, en-main)
# (Re)launches the dev app in debug on the screenshots simulator, signed in as that
# demo account. See wishlist/lib/app/dev/store_screenshot_mode.dart.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
KEY=${1:?usage: run.sh <account-key>}
UDID=$("$HERE/simulator.sh" udid)
[[ -n "$UDID" ]] || { echo "simulator not found, run ./simulator.sh setup" >&2; exit 1; }

# argv instead of string interpolation, so special characters are safe
read_cred() { node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))[process.argv[2]][process.argv[3]])" "$HERE/.accounts.json" "$KEY" "$1"; }
EMAIL=$(read_cred email)
PASSWORD=$(read_cred password)

ROUTE_FILE="$HERE/.route.txt"
LOG="$HERE/.flutter-run.log"
: > "$ROUTE_FILE"

pkill -f "flutter_tools.snapshot run -d $UDID" 2>/dev/null || true
sleep 2

cd "$HERE/../../wishlist"
nohup flutter run -d "$UDID" \
  --dart-define=APP_ENV=dev --dart-define=APP_ID_SUFFIX=.dev "--dart-define=APP_NAME_PREFIX=[DEV]" \
  "--dart-define=SHOTS_EMAIL=$EMAIL" "--dart-define=SHOTS_PASSWORD=$PASSWORD" \
  "--dart-define=SHOTS_ROUTE_FILE=$ROUTE_FILE" > "$LOG" 2>&1 &

for _ in $(seq 1 120); do
  grep -qE "Flutter run key commands|Could not build|Error launching" "$LOG" && break
  sleep 5
done
grep -q "Flutter run key commands" "$LOG" || { echo "app did not start, see $LOG" >&2; exit 1; }
echo "app running" 
