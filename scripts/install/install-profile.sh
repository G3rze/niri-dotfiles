write_profile_array() {
  local array_name="$1"
  local -n array_ref="$2"
  local item

  printf "declare -a %s=(" "${array_name}"
  for item in "${array_ref[@]}"; do
    printf " %q" "${item}"
  done
  printf " )\n"
}

load_install_profile() {
  if [[ ! -f "${INSTALL_PROFILE_FILE}" ]]; then
    return 1
  fi

  # shellcheck disable=SC1090
  source "${INSTALL_PROFILE_FILE}"
  INSTALL_PROFILE_LOADED=true
  return 0
}

save_install_profile() {
  mkdir -p "${INSTALL_STATE_DIR}"

  {
    printf "CONFIGURE_FISH=%q\n" "${CONFIGURE_FISH}"
    printf "CONFIGURE_ZSH=%q\n" "${CONFIGURE_ZSH}"
    printf "SELECTED_XKB_LAYOUT=%q\n" "${SELECTED_XKB_LAYOUT}"
    printf "SELECTED_XKB_OPTIONS=%q\n" "${SELECTED_XKB_OPTIONS}"
    printf "SELECTED_LANG=%q\n" "${SELECTED_LANG}"
    printf "INSTALL_XWAYLAND=%q\n" "${INSTALL_XWAYLAND}"
    printf "INSTALL_XWAYLAND_BRIDGE=%q\n" "${INSTALL_XWAYLAND_BRIDGE}"
    printf "INSTALL_STEAM=%q\n" "${INSTALL_STEAM}"
    printf "INSTALL_DISCORD=%q\n" "${INSTALL_DISCORD}"
    printf "INSTALL_RETROARCH=%q\n" "${INSTALL_RETROARCH}"
    printf "INSTALL_SPOTIFY=%q\n" "${INSTALL_SPOTIFY}"
    printf "INSTALL_LIBREOFFICE=%q\n" "${INSTALL_LIBREOFFICE}"
    printf "INSTALL_ONLYOFFICE=%q\n" "${INSTALL_ONLYOFFICE}"
    printf "INSTALL_SYNCTHING=%q\n" "${INSTALL_SYNCTHING}"
    printf "INSTALL_DOCKER=%q\n" "${INSTALL_DOCKER}"
    printf "INSTALL_CODE=%q\n" "${INSTALL_CODE}"
    printf "INSTALL_NVM=%q\n" "${INSTALL_NVM}"
    printf "INSTALL_NODE_LTS=%q\n" "${INSTALL_NODE_LTS}"
    printf "INSTALL_CODEX_CLI=%q\n" "${INSTALL_CODEX_CLI}"
    printf "SELECTED_JAVA_PACKAGE=%q\n" "${SELECTED_JAVA_PACKAGE}"
    printf "SELECTED_GPU_SESSION_MODE=%q\n" "${SELECTED_GPU_SESSION_MODE}"
    printf "SELECTED_INTEL_DRIVER_PROFILE=%q\n" "${SELECTED_INTEL_DRIVER_PROFILE}"
    printf "SELECTED_AMD_DRIVER_PROFILE=%q\n" "${SELECTED_AMD_DRIVER_PROFILE}"
    printf "SELECTED_NVIDIA_DRIVER_PACKAGE=%q\n" "${SELECTED_NVIDIA_DRIVER_PACKAGE}"
    printf "DETECTED_GPU_INTEL_NAME=%q\n" "${DETECTED_GPU_INTEL_NAME}"
    printf "DETECTED_GPU_AMD_NAME=%q\n" "${DETECTED_GPU_AMD_NAME}"
    printf "DETECTED_GPU_NVIDIA_NAME=%q\n" "${DETECTED_GPU_NVIDIA_NAME}"
    write_profile_array "SELECTED_OPTIONAL_PACMAN_PACKAGES" SELECTED_OPTIONAL_PACMAN_PACKAGES
    write_profile_array "SELECTED_OPTIONAL_AUR_PACKAGES" SELECTED_OPTIONAL_AUR_PACKAGES
  } > "${INSTALL_PROFILE_FILE}"

  add_summary "Install profile saved to ${INSTALL_PROFILE_FILE}"
}
