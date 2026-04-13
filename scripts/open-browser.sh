#!/usr/bin/env bash

set -euo pipefail

mode="${1:-primary}"

launch_browser() {
  local browser="$1"
  shift || true

  if command -v "$browser" >/dev/null 2>&1; then
    exec "$browser" "$@"
  fi
}

case "$mode" in
  primary)
    launch_browser zen-browser
    launch_browser firefox
    launch_browser google-chrome-stable --enable-features=TouchpadOverscrollHistoryNavigation
    launch_browser chromium
    ;;
  secondary)
    launch_browser firefox
    launch_browser google-chrome-stable --enable-features=TouchpadOverscrollHistoryNavigation
    launch_browser chromium
    launch_browser zen-browser
    ;;
  *)
    printf 'Usage: %s {primary|secondary}\n' "${0##*/}" >&2
    exit 1
    ;;
esac

if command -v notify-send >/dev/null 2>&1; then
  notify-send --app-name="Browser Launcher" "No supported browser found" \
    "Install zen-browser, firefox, chromium, or google-chrome-stable."
fi

exit 1
