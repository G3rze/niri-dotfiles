#!/usr/bin/env bash

set -euo pipefail

launch_if_present() {
  local cmd="$1"
  shift || true

  if command -v "$cmd" >/dev/null 2>&1; then
    exec "$cmd" "$@"
  fi
}

launch_if_present thunar
launch_if_present nautilus

if command -v kitty >/dev/null 2>&1 && command -v yazi >/dev/null 2>&1; then
  exec kitty -e yazi
fi

if command -v alacritty >/dev/null 2>&1 && command -v yazi >/dev/null 2>&1; then
  exec alacritty -e yazi
fi

if command -v xdg-open >/dev/null 2>&1; then
  exec xdg-open "$HOME"
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send --app-name="File Manager Launcher" "No file manager found" \
    "Install thunar, nautilus, or yazi."
fi

exit 1
