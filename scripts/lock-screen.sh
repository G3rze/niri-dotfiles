#!/usr/bin/env bash

set -euo pipefail

readonly LOCK_BG_SCRIPT="${HOME}/.config/scripts/update-lockscreen-background.sh"
readonly LOCK_THEME_SCRIPT="${HOME}/.config/scripts/update-gtklock-theme.sh"
readonly LOCK_BG_FILE="${HOME}/.cache/gtklock/lockscreen-blur.png"

if [[ -x "${LOCK_BG_SCRIPT}" ]]; then
  "${LOCK_BG_SCRIPT}" >/dev/null 2>&1 || true
fi

if [[ -x "${LOCK_THEME_SCRIPT}" ]]; then
  "${LOCK_THEME_SCRIPT}" >/dev/null 2>&1 || true
fi

if [[ -f "${LOCK_BG_FILE}" ]]; then
  exec gtklock -b "${LOCK_BG_FILE}"
fi

exec gtklock
