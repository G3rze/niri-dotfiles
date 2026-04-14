#!/usr/bin/env bash

set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name="Clipboard" "cliphist is not installed"
  fi
  exit 1
fi

if ! command -v wl-copy >/dev/null 2>&1; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name="Clipboard" "wl-clipboard is not installed"
  fi
  exit 1
fi

if ! command -v rofi >/dev/null 2>&1; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name="Clipboard" "rofi is not installed"
  fi
  exit 1
fi

selection="$(
  cliphist list | rofi -dmenu -i -p "Clipboard"
)"

if [[ -z "${selection}" ]]; then
  exit 0
fi

cliphist decode <<< "${selection}" | wl-copy
