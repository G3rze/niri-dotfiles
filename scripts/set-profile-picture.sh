#!/usr/bin/env bash

set -euo pipefail

readonly USERNAME="${SUDO_USER:-${USER}}"
readonly SOURCE_IMAGE="${1:-}"
readonly TEMP_DIR="$(mktemp -d)"
readonly SQUARE_IMAGE="${TEMP_DIR}/profile-square.png"
readonly ACCOUNTS_ICON="/var/lib/AccountsService/icons/${USERNAME}"
readonly ACCOUNTS_USER="/var/lib/AccountsService/users/${USERNAME}"
readonly SDDM_ICON="/usr/share/sddm/faces/${USERNAME}.face.icon"

cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

print_help() {
  cat <<'EOF'
Usage:
  gerzeos --set-profile-picture <path>

Supported image formats:
  Any format readable by ImageMagick's 'magick' command.
  Common formats: .png .jpg .jpeg .webp .bmp .tif .tiff .gif .avif
EOF
}

require_binary() {
  local binary="$1"
  if ! command -v "${binary}" >/dev/null 2>&1; then
    printf 'error: required binary not found: %s\n' "${binary}" >&2
    exit 1
  fi
}

write_accountsservice_file() {
  local temp_file="${TEMP_DIR}/accountsservice-user.conf"
  cat > "${temp_file}" <<EOF
[User]
Icon=${ACCOUNTS_ICON}
EOF
  sudo install -Dm644 "${temp_file}" "${ACCOUNTS_USER}"
}

main() {
  if [[ -z "${SOURCE_IMAGE}" ]] || [[ "${SOURCE_IMAGE}" == "-h" ]] || [[ "${SOURCE_IMAGE}" == "--help" ]]; then
    print_help
    exit 0
  fi

  require_binary magick
  require_binary sudo

  if [[ ! -f "${SOURCE_IMAGE}" ]]; then
    printf 'error: image not found: %s\n' "${SOURCE_IMAGE}" >&2
    exit 1
  fi

  magick "${SOURCE_IMAGE}" -auto-orient -gravity center -crop 1:1 +repage -resize 256x256 "${SQUARE_IMAGE}"

  sudo install -Dm644 "${SQUARE_IMAGE}" "${ACCOUNTS_ICON}"
  sudo install -Dm644 "${SQUARE_IMAGE}" "${SDDM_ICON}"
  write_accountsservice_file

  printf 'Profile picture updated for %s\n' "${USERNAME}"
  printf '  AccountsService: %s\n' "${ACCOUNTS_ICON}"
  printf '  SDDM: %s\n' "${SDDM_ICON}"
}

main "$@"
