#!/usr/bin/env bash

set -euo pipefail

resolve_user_home() {
  if [[ -n "${SUDO_USER:-}" ]]; then
    getent passwd "${SUDO_USER}" | cut -d: -f6
    return
  fi

  printf '%s\n' "${HOME}"
}

readonly USER_HOME="$(resolve_user_home)"
readonly TARGET_DIR="${SDDM_DYNAMIC_DIR:-/var/lib/sddm/silent-dynamic}"
readonly BG_DIR="${TARGET_DIR}/backgrounds"
readonly BG_FILE="${BG_DIR}/dynamic.jpg"
readonly CONF_FILE="${TARGET_DIR}/configs/default.conf"
readonly WALLUST_COLORS="${USER_HOME}/.cache/wallust/colors.json"

mkdir -p "${BG_DIR}"

get_current_wallpaper() {
  if command -v awww >/dev/null 2>&1; then
    local queried_path=""
    queried_path="$(awww query 2>/dev/null | grep -oP '(?<=image: ).*' | head -n1 | tr -d '\n\r' || true)"
    if [[ -n "${queried_path}" ]]; then
      printf '%s\n' "${queried_path}"
      return 0
    fi
  fi

  local cache_root="${USER_HOME}/.cache/awww"
  local cache_file=""
  cache_file="$(find "${cache_root}" -maxdepth 2 -type f 2>/dev/null | head -n1 || true)"

  if [[ -n "${cache_file}" && -f "${cache_file}" ]]; then
    strings -n 1 "${cache_file}" | grep '^/' | tail -n1 | tr -d '\n\r'
  fi
}

wallpaper_path="${1:-}"
if [[ -z "${wallpaper_path}" ]]; then
  wallpaper_path="$(get_current_wallpaper)"
fi

if [[ -z "${wallpaper_path}" || ! -f "${wallpaper_path}" ]]; then
  exit 1
fi

if [[ ! -f "${WALLUST_COLORS}" || ! -f "${CONF_FILE}" ]]; then
  exit 1
fi

background="$(jq -r '.special.background' "${WALLUST_COLORS}")"
foreground="$(jq -r '.special.foreground' "${WALLUST_COLORS}")"
accent="$(jq -r '.colors.color4 // .colors.color2 // .special.foreground' "${WALLUST_COLORS}")"
accent_fg="$(jq -r '.special.foreground' "${WALLUST_COLORS}")"
muted="$(jq -r '.colors.color8 // .colors.color7 // .special.foreground' "${WALLUST_COLORS}")"
border="$(jq -r '.special.background' "${WALLUST_COLORS}")"
error="$(jq -r '.colors.color1 // "#ff5f56"' "${WALLUST_COLORS}")"
input_bg="$(jq -r '.colors.color0 // .special.background' "${WALLUST_COLORS}")"
input_fg="$(jq -r '.special.foreground' "${WALLUST_COLORS}")"
input_border="$(jq -r '.colors.color8 // .special.foreground' "${WALLUST_COLORS}")"

set_ini_value() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local escaped_value

  if grep -q "^\\[${section}\\]" "${file}"; then
    if sed -n "/^\\[${section}\\]/,/^\\[/p" "${file}" | grep -q "^${key}[[:space:]]*="; then
      escaped_value="$(printf '%s' "${value}" | sed 's/[&|]/\\&/g')"
      sed -i "/^\\[${section}\\]/,/^\\[/ s|^${key}[[:space:]]*=.*|${key} = ${escaped_value}|" "${file}"
    else
      sed -i "/^\\[${section}\\]/a ${key} = ${value}" "${file}"
    fi
  else
    printf '\n[%s]\n%s = %s\n' "${section}" "${key}" "${value}" >> "${file}"
  fi
}

tmp_bg="${BG_FILE}.tmp"
magick "${wallpaper_path}" \
  -strip \
  -resize 2560x1440^ \
  -gravity center \
  -extent 2560x1440 \
  -brightness-contrast -8x-4 \
  "${tmp_bg}"
mv "${tmp_bg}" "${BG_FILE}"

set_ini_value "${CONF_FILE}" "LockScreen" "background" "\"dynamic.jpg\""
set_ini_value "${CONF_FILE}" "LockScreen" "use-background-color" "false"
set_ini_value "${CONF_FILE}" "LockScreen" "background-color" "\"${background}\""

set_ini_value "${CONF_FILE}" "LockScreen.Clock" "color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LockScreen.Date" "color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LockScreen.Message" "color" "\"${foreground}\""

set_ini_value "${CONF_FILE}" "LoginScreen" "background" "\"dynamic.jpg\""
set_ini_value "${CONF_FILE}" "LoginScreen" "use-background-color" "false"
set_ini_value "${CONF_FILE}" "LoginScreen" "background-color" "\"${background}\""

set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Avatar" "active-size" "144"
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Avatar" "inactive-size" "96"
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Avatar" "active-border-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Avatar" "inactive-border-color" "\"${foreground}\""

set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Username" "color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Username" "font-size" "18"
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Username" "margin" "12"
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.PasswordInput" "content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.PasswordInput" "background-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.PasswordInput" "border-color" "\"${input_border}\""

set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.LoginButton" "background-color" "\"${accent}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.LoginButton" "active-background-color" "\"${accent}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.LoginButton" "content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.LoginButton" "active-content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.LoginButton" "border-color" "\"${border}\""

set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.Spinner" "color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.WarningMessage" "normal-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.WarningMessage" "warning-color" "\"${muted}\""
set_ini_value "${CONF_FILE}" "LoginScreen.LoginArea.WarningMessage" "error-color" "\"${error}\""

set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Popups" "background-color" "\"${input_bg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Popups" "active-option-background-color" "\"${accent}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Popups" "content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Popups" "active-content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Popups" "border-color" "\"${border}\""

set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Session" "content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Session" "active-content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Session" "background-color" "\"${input_bg}\""

set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Layout" "content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Layout" "active-content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Layout" "background-color" "\"${input_bg}\""

set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Keyboard" "content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Keyboard" "active-content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Keyboard" "background-color" "\"${input_bg}\""

set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Power" "content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Power" "active-content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.MenuArea.Power" "background-color" "\"${input_bg}\""

set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "background-color" "\"${input_bg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "key-content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "key-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "key-active-background-color" "\"${accent}\""
set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "selection-background-color" "\"${accent}\""
set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "selection-content-color" "\"${accent_fg}\""
set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "primary-color" "\"${accent}\""
set_ini_value "${CONF_FILE}" "LoginScreen.VirtualKeyboard" "border-color" "\"${border}\""

set_ini_value "${CONF_FILE}" "Tooltips" "content-color" "\"${foreground}\""
set_ini_value "${CONF_FILE}" "Tooltips" "background-color" "\"${input_bg}\""
