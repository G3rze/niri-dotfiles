#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

MODE_RAW="${1:-auto}"
MODE="$(printf '%s' "${MODE_RAW}" | tr '[:upper:]' '[:lower:]')"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}"
LOG_FILE="${CACHE_DIR}/niri-gpu-session.log"

mkdir -p "${CACHE_DIR}"

join_by() {
  local delimiter="$1"
  shift
  local out=""
  local item
  for item in "$@"; do
    if [[ -z "${out}" ]]; then
      out="${item}"
    else
      out="${out}${delimiter}${item}"
    fi
  done
  printf '%s\n' "${out}"
}

map_vendor_cards() {
  local vendor_hex="$1"
  local node real_node card pci_addr vendor
  local -a cards=()

  if ! command -v lspci >/dev/null 2>&1; then
    printf '\n'
    return 0
  fi

  if [[ ! -d /dev/dri/by-path ]]; then
    printf '\n'
    return 0
  fi

  for node in /dev/dri/by-path/pci-*-card; do
    [[ -e "${node}" ]] || continue
    real_node="$(readlink -f "${node}" || true)"
    card="$(basename "${real_node}")"
    pci_addr="$(basename "${node}")"
    pci_addr="${pci_addr#pci-}"
    pci_addr="${pci_addr%-card}"
    vendor="$(lspci -nns "${pci_addr}" 2> /dev/null | awk -F'[][]' '/VGA|3D|Display/{print $3; exit}' | awk -F: '{print tolower($1)}' || true)"
    if [[ "${vendor}" == "${vendor_hex}" ]]; then
      cards+=("/dev/dri/${card}")
    fi
  done

  join_by ":" "${cards[@]}"
}

INTEL_CARDS="$(map_vendor_cards "8086")"
AMD_CARDS="$(map_vendor_cards "1002")"
NVIDIA_CARDS="$(map_vendor_cards "10de")"

export SEVENS_GPU_MODE="${MODE}"
export SEVENS_DRM_INTEL_CARDS="${INTEL_CARDS}"
export SEVENS_DRM_AMD_CARDS="${AMD_CARDS}"
export SEVENS_DRM_NVIDIA_CARDS="${NVIDIA_CARDS}"

case "${MODE}" in
  intel)
    export DRI_PRIME=0
    export __NV_PRIME_RENDER_OFFLOAD=0
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    unset __VK_LAYER_NV_optimus
    ;;
  nvidia)
    export DRI_PRIME=1
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    export GBM_BACKEND=nvidia-drm
    ;;
  amd)
    export DRI_PRIME=1
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    unset __NV_PRIME_RENDER_OFFLOAD
    unset __VK_LAYER_NV_optimus
    ;;
  *)
    MODE="auto"
    export SEVENS_GPU_MODE="${MODE}"
    ;;
esac

{
  printf '[%s] mode=%s intel=%s amd=%s nvidia=%s\n' \
    "$(date +'%Y-%m-%d %H:%M:%S')" \
    "${MODE}" \
    "${INTEL_CARDS:-none}" \
    "${AMD_CARDS:-none}" \
    "${NVIDIA_CARDS:-none}"
} >> "${LOG_FILE}" 2> /dev/null || true

exec niri-session
