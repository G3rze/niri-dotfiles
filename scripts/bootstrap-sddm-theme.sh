#!/usr/bin/env bash

set -euo pipefail

readonly BASE_THEME_NAME="silent"
readonly THEME_NAME="silent-dynamic"
readonly SOURCE_THEME_DIR="/usr/share/sddm/themes/${BASE_THEME_NAME}"
readonly TARGET_THEME_DIR="/var/lib/sddm/${THEME_NAME}"
readonly LINK_PATH="/usr/share/sddm/themes/${THEME_NAME}"
readonly CONF_DIR="/etc/sddm.conf.d"
readonly CONF_FILE="${CONF_DIR}/10-${THEME_NAME}.conf"
readonly OWNER_USER="${SUDO_USER:-${PKEXEC_UID:+$(id -nu "${PKEXEC_UID}")}}"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'Run as root.\n' >&2
  exit 1
fi

id sddm >/dev/null 2>&1 || {
  printf 'sddm user not found.\n' >&2
  exit 1
}

if [[ -z "${OWNER_USER}" ]]; then
  printf 'Could not determine target desktop user. Run with sudo from the user session.\n' >&2
  exit 1
fi

if [[ ! -d "${SOURCE_THEME_DIR}" ]]; then
  printf 'Base theme not installed: %s\n' "${SOURCE_THEME_DIR}" >&2
  exit 1
fi

install -d -m 0755 "${TARGET_THEME_DIR}" "${CONF_DIR}"
cp -a "${SOURCE_THEME_DIR}/." "${TARGET_THEME_DIR}/"

if [[ -d "${TARGET_THEME_DIR}/backgrounds" ]]; then
  touch "${TARGET_THEME_DIR}/backgrounds/dynamic.jpg"
fi

chown -R "${OWNER_USER}:sddm" "${TARGET_THEME_DIR}"
find "${TARGET_THEME_DIR}" -type d -exec chmod 0755 {} +
find "${TARGET_THEME_DIR}" -type f -exec chmod 0644 {} +
chmod u+w "${TARGET_THEME_DIR}/configs/default.conf" "${TARGET_THEME_DIR}/backgrounds/dynamic.jpg" 2>/dev/null || true

ln -sfn "${TARGET_THEME_DIR}" "${LINK_PATH}"

cat > "${CONF_FILE}" <<EOF
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=${LINK_PATH}/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=${THEME_NAME}
EOF

printf 'SDDM dynamic theme installed at %s\n' "${TARGET_THEME_DIR}"
