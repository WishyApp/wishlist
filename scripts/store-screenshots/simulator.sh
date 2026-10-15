#!/bin/bash
# Simulator helpers. Usage: simulator.sh setup | lang fr|en | udid
# The device is looked up by name, never by UDID.
set -euo pipefail

NAME="Wishy Shots 17PM"

udid() {
  xcrun simctl list devices | grep -F "$NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true
}

case "${1:-}" in
  udid)
    udid
    ;;
  setup)
    U=$(udid)
    if [[ -z "$U" ]]; then
      RUNTIME=$(xcrun simctl list runtimes | grep -E '^iOS' | tail -1 | sed -E 's/.*(com\.apple\.CoreSimulator\.SimRuntime\.[A-Za-z0-9-]+).*/\1/')
      U=$(xcrun simctl create "$NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max "$RUNTIME")
    fi
    xcrun simctl boot "$U" 2>/dev/null || true
    xcrun simctl bootstatus "$U" -b >/dev/null
    xcrun simctl status_bar "$U" override --time "9:41" --batteryState charged --batteryLevel 100 \
      --cellularBars 4 --wifiBars 3 --dataNetwork wifi
    open -a Simulator
    echo "simulator ready: $U"
    ;;
  lang)
    L=${2:?usage: simulator.sh lang fr|en}
    case "$L" in fr) LOCALE=fr_FR ;; en) LOCALE=en_US ;; *) echo "lang must be fr or en" >&2; exit 1 ;; esac
    U=$(udid)
    xcrun simctl spawn "$U" defaults write -g AppleLanguages -array "$L"
    xcrun simctl spawn "$U" defaults write -g AppleLocale "$LOCALE"
    xcrun simctl shutdown "$U" 2>/dev/null || true
    "$0" setup
    ;;
  *)
    echo "usage: simulator.sh setup | lang fr|en | udid" >&2
    exit 1
    ;;
esac
