#!/usr/bin/env bash

set -euo pipefail

readonly CACHE_DIR="${HOME}/.cache/gtklock"
readonly OUTPUT_FILE="${CACHE_DIR}/lockscreen-blur.png"
readonly STATE_FILE="${CACHE_DIR}/lockscreen-source"
readonly DEFAULT_SOURCE="${HOME}/Pictures/Wallpapers"

mkdir -p "${CACHE_DIR}"

get_current_wallpaper() {
  if command -v awww >/dev/null 2>&1; then
    local queried_path=""
    queried_path="$(awww query 2>/dev/null | grep -oP '(?<=image: ).*' | head -n1 | tr -d '\n\r' || true)"
    if [[ -n "${queried_path}" ]]; then
      printf '%s\n' "${queried_path}"
      return 0
    fi
  fi

  local cache_root="${HOME}/.cache/awww"
  local cache_file=""
  cache_file="$(find "${cache_root}" -maxdepth 2 -type f 2>/dev/null | head -n1 || true)"

  if [[ -n "${cache_file}" && -f "${cache_file}" ]]; then
    strings -n 1 "${cache_file}" | grep '^/' | tail -n1 | tr -d '\n\r'
  fi
}

source_path="${1:-}"
if [[ -z "${source_path}" ]]; then
  source_path="$(get_current_wallpaper)"
fi

if [[ -z "${source_path}" || ! -f "${source_path}" ]]; then
  exit 1
fi

current_state="${source_path}|$(stat -c '%Y' "${source_path}")"
if [[ -f "${STATE_FILE}" && -f "${OUTPUT_FILE}" ]] && [[ "$(cat "${STATE_FILE}")" == "${current_state}" ]]; then
  printf '%s\n' "${OUTPUT_FILE}"
  exit 0
fi

tmp_output="${OUTPUT_FILE}.tmp"

magick "${source_path}" \
  -strip \
  -resize 1920x1080^ \
  -gravity center \
  -extent 1920x1080 \
  -blur 0x16 \
  -brightness-contrast -10x-5 \
  "${tmp_output}"

mv "${tmp_output}" "${OUTPUT_FILE}"
printf '%s' "${current_state}" > "${STATE_FILE}"
printf '%s\n' "${OUTPUT_FILE}"
