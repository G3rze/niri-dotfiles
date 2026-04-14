prompt_yes_no() {
  local prompt="$1"
  local default_answer="${2:-N}"
  local reply

  read -r -p "${prompt}" reply < /dev/tty

  if [[ -z "${reply}" ]]; then
    reply="${default_answer}"
  fi

  [[ "${reply}" =~ ^[Yy]$ ]]
}

add_optional_pacman_package() {
  local package="$1"
  local existing

  for existing in "${SELECTED_OPTIONAL_PACMAN_PACKAGES[@]}"; do
    if [[ "${existing}" == "${package}" ]]; then
      return 0
    fi
  done

  SELECTED_OPTIONAL_PACMAN_PACKAGES+=("${package}")
}

add_optional_aur_package() {
  local package="$1"
  local existing

  for existing in "${SELECTED_OPTIONAL_AUR_PACKAGES[@]}"; do
    if [[ "${existing}" == "${package}" ]]; then
      return 0
    fi
  done

  SELECTED_OPTIONAL_AUR_PACKAGES+=("${package}")
}

add_optional_package() {
  local package="$1"

  if pacman -Si "${package}" >> "${LOG_FILE}" 2>&1; then
    add_optional_pacman_package "${package}"
  else
    add_optional_aur_package "${package}"
  fi
}

is_java_lts_version() {
  local major="$1"

  if [[ "${major}" == "8" ]] || [[ "${major}" == "11" ]]; then
    return 0
  fi

  if [[ "${major}" =~ ^[0-9]+$ ]] && (( major >= 17 )) && (((major - 17) % 4 == 0)); then
    return 0
  fi

  return 1
}

select_java_package() {
  local latest_pkg=""
  local line pkg version_major
  local -a lts_entries=()
  local -a menu_labels=("Skip Java installation")
  local -a menu_packages=("")
  local reply choice

  while IFS= read -r line; do
    pkg="$(awk '{print $1}' <<< "${line}")"
    pkg="${pkg#*/}"

    case "${pkg}" in
      jdk-openjdk)
        latest_pkg="${pkg}"
        ;;
      jdk[0-9]*-openjdk)
        version_major="${pkg#jdk}"
        version_major="${version_major%-openjdk}"
        if is_java_lts_version "${version_major}"; then
          lts_entries+=("${version_major}:${pkg}")
        fi
        ;;
    esac
  done < <(pacman -Ss '^jdk[0-9]*-openjdk$|^jdk-openjdk$' 2> /dev/null)

  if [[ -n "${latest_pkg}" ]]; then
    menu_labels+=("Latest feature release (${latest_pkg})")
    menu_packages+=("${latest_pkg}")
  fi

  if [[ ${#lts_entries[@]} -gt 0 ]]; then
    mapfile -t lts_entries < <(printf '%s\n' "${lts_entries[@]}" | sort -t: -k1,1nr | head -n 3)

    for line in "${lts_entries[@]}"; do
      version_major="${line%%:*}"
      pkg="${line#*:}"
      menu_labels+=("Java ${version_major} LTS (${pkg})")
      menu_packages+=("${pkg}")
    done
  fi

  if [[ ${#menu_labels[@]} -eq 1 ]]; then
    warn "No OpenJDK packages were detected in pacman metadata. Skipping Java selection."
    return 0
  fi

  printf "\n"
  printf "${BLUE}${BOLD}Java Toolchain${NC}\n"
  printf "Choose one JDK to install, or skip Java entirely.\n"
  printf "\n"

  choice=1
  for line in "${menu_labels[@]}"; do
    printf "  %d) %s\n" "${choice}" "${line}"
    ((choice++)) || true
  done
  printf "\n"

  read -r -p "Choose Java option (1-$(( ${#menu_labels[@]} ))) [default: 1]: " reply < /dev/tty

  if [[ -z "${reply}" ]]; then
    reply="1"
  fi

  if [[ ! "${reply}" =~ ^[0-9]+$ ]] || (( reply < 1 || reply > ${#menu_packages[@]} )); then
    warn "Invalid Java selection. Skipping Java installation."
    return 0
  fi

  SELECTED_JAVA_PACKAGE="${menu_packages[$((reply - 1))]}"

  if [[ -n "${SELECTED_JAVA_PACKAGE}" ]]; then
    add_optional_package "${SELECTED_JAVA_PACKAGE}"
    msg "Selected Java package: ${SELECTED_JAVA_PACKAGE}"
  else
    info "Skipping Java installation."
  fi
}

install_pacman_packages() {
  info "Installing official repository packages..."
  info "This may take several minutes..."

  local packages_to_install=("${PACMAN_PACKAGES[@]}" "${SELECTED_OPTIONAL_PACMAN_PACKAGES[@]}")

  if sudo pacman -S --needed --noconfirm "${packages_to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
    msg "Official packages installed successfully."
  else
    fatal "Failed to install official repository packages."
  fi
}

install_aur_packages() {
  info "Installing AUR packages using ${AUR_HELPER}..."
  info "This may take several minutes..."

  local packages_to_install=("${AUR_PACKAGES[@]}" "${SELECTED_OPTIONAL_AUR_PACKAGES[@]}")

  if "${AUR_HELPER}" -S --needed --noconfirm "${packages_to_install[@]}" 2>&1 | tee -a "${LOG_FILE}"; then
    msg "AUR packages installed successfully."
  else
    fatal "Failed to install AUR packages."
  fi
}

configure_optional_installs() {
  if [[ "${REPAIR_MODE}" == "true" ]] && [[ "${INSTALL_PROFILE_LOADED}" == "true" ]]; then
    info "Repair mode: reusing saved optional package selections from ${INSTALL_PROFILE_FILE}"
    add_summary "Repair mode reused saved optional package selections"
    return 0
  fi

  info "Selecting optional desktop packages and developer tools..."
  printf "\n"
  printf "${BLUE}${BOLD}Optional Packages${NC}\n"
  printf "Choose which extra desktop applications should be installed by this run.\n"
  printf "\n"

  if prompt_yes_no "Install Steam? (y/N): " "N"; then
    INSTALL_STEAM=true
    INSTALL_XWAYLAND=true
    INSTALL_XWAYLAND_BRIDGE=true
    add_optional_package "steam"
    add_optional_package "xorg-xwayland"
    add_optional_package "xwayland-satellite"
    msg "Selected: Steam"
    info "Steam selected, so XWayland and xwayland-satellite will also be installed."
  else
    info "Skipping Steam."
  fi

  if prompt_yes_no "Install Discord? (y/N): " "N"; then
    INSTALL_DISCORD=true
    add_optional_package "discord"
    msg "Selected: Discord"
  else
    info "Skipping Discord."
  fi

  if prompt_yes_no "Install RetroArch? (y/N): " "N"; then
    INSTALL_RETROARCH=true
    add_optional_package "retroarch"
    msg "Selected: RetroArch"
  else
    info "Skipping RetroArch."
  fi

  if prompt_yes_no "Install Spotify? (spotify-launcher) (y/N): " "N"; then
    INSTALL_SPOTIFY=true
    add_optional_package "spotify-launcher"
    msg "Selected: Spotify"
  else
    info "Skipping Spotify."
  fi

  if prompt_yes_no "Install LibreOffice? (y/N): " "N"; then
    INSTALL_LIBREOFFICE=true
    add_optional_package "libreoffice-fresh"
    msg "Selected: LibreOffice"
  else
    info "Skipping LibreOffice."
  fi

  if prompt_yes_no "Install OnlyOffice? (y/N): " "N"; then
    INSTALL_ONLYOFFICE=true
    add_optional_package "onlyoffice-bin"
    msg "Selected: OnlyOffice"
  else
    info "Skipping OnlyOffice."
  fi

  if prompt_yes_no "Install Syncthing? (y/N): " "N"; then
    INSTALL_SYNCTHING=true
    add_optional_package "syncthing"
    msg "Selected: Syncthing"
  else
    info "Skipping Syncthing."
  fi

  printf "\n"
  printf "${BLUE}${BOLD}Optional Developer Tools${NC}\n"
  printf "You can enable each tool independently.\n"
  printf "\n"

  if prompt_yes_no "Install Docker? (y/N): " "N"; then
    INSTALL_DOCKER=true
    add_optional_package "docker"
    msg "Selected: Docker"
  else
    info "Skipping Docker."
  fi

  if prompt_yes_no "Install Code - OSS? (y/N): " "N"; then
    INSTALL_CODE=true
    add_optional_package "code"
    msg "Selected: Code - OSS"
  else
    info "Skipping Code - OSS."
  fi

  select_java_package

  if prompt_yes_no "Install nvm? (y/N): " "N"; then
    INSTALL_NVM=true
    msg "Selected: nvm"
  else
    info "Skipping nvm."
  fi

  if prompt_yes_no "Install Node.js LTS via nvm? (y/N): " "N"; then
    INSTALL_NODE_LTS=true
    INSTALL_NVM=true
    msg "Selected: Node.js LTS via nvm"
  else
    info "Skipping Node.js LTS."
  fi

  printf "\n"
  info "OpenAI Codex CLI install is optional."
  info "Requires ChatGPT Plus or a valid OpenAI API key."
  if prompt_yes_no "Install OpenAI Codex CLI (npm i -g @openai/codex)? (y/N): " "N"; then
    INSTALL_CODEX_CLI=true
    msg "Selected: OpenAI Codex CLI"
  else
    info "Skipping OpenAI Codex CLI."
  fi

  if [[ ${#SELECTED_OPTIONAL_PACMAN_PACKAGES[@]} -gt 0 ]]; then
    add_summary "Optional pacman packages selected: ${SELECTED_OPTIONAL_PACMAN_PACKAGES[*]}"
  else
    add_summary "No optional pacman packages selected"
  fi

  if [[ ${#SELECTED_OPTIONAL_AUR_PACKAGES[@]} -gt 0 ]]; then
    add_summary "Optional AUR packages selected: ${SELECTED_OPTIONAL_AUR_PACKAGES[*]}"
  fi
}

detect_nvidia_arch_family() {
  local gpu_name_lc="$1"

  if [[ "${gpu_name_lc}" =~ rtx[[:space:]]?50|rtx[[:space:]]?40|rtx[[:space:]]?30|rtx[[:space:]]?20|a[0-9]{3,4}|ada|ampere|turing ]]; then
    printf 'modern\n'
    return 0
  fi

  if [[ "${gpu_name_lc}" =~ gtx[[:space:]]?10|gtx[[:space:]]?9|pascal|maxwell ]]; then
    printf 'legacy470\n'
    return 0
  fi

  if [[ "${gpu_name_lc}" =~ kepler|fermi|g[tf]x[[:space:]]?[4-8][0-9]{2} ]]; then
    printf 'legacy390\n'
    return 0
  fi

  printf 'unknown\n'
}

add_nvidia_driver_bundle() {
  local driver_pkg="$1"

  add_optional_package "${driver_pkg}"

  case "${driver_pkg}" in
    nvidia-dkms|nvidia)
      add_optional_package "nvidia-utils"
      add_optional_package "nvidia-settings"
      add_optional_package "lib32-nvidia-utils"
      ;;
    nvidia-open-dkms|nvidia-open)
      add_optional_package "nvidia-utils"
      add_optional_package "nvidia-settings"
      add_optional_package "lib32-nvidia-utils"
      ;;
    nvidia-470xx-dkms)
      add_optional_package "nvidia-470xx-utils"
      add_optional_package "nvidia-settings"
      add_optional_package "lib32-nvidia-470xx-utils"
      ;;
    nvidia-390xx-dkms)
      add_optional_package "nvidia-390xx-utils"
      add_optional_package "nvidia-settings"
      ;;
  esac
}

select_nvidia_driver() {
  local nvidia_name="$1"
  local family recommended current_driver menu_max reply default_reply
  local -a menu_labels=()
  local -a menu_values=()

  family="$(detect_nvidia_arch_family "$(printf '%s' "${nvidia_name}" | tr '[:upper:]' '[:lower:]')")"

  case "${family}" in
    modern) recommended="nvidia-dkms" ;;
    legacy470) recommended="nvidia-470xx-dkms" ;;
    legacy390) recommended="nvidia-390xx-dkms" ;;
    *) recommended="" ;;
  esac

  current_driver=""
  if pacman -Q nvidia-dkms >> "${LOG_FILE}" 2>&1; then
    current_driver="nvidia-dkms"
  elif pacman -Q nvidia-open-dkms >> "${LOG_FILE}" 2>&1; then
    current_driver="nvidia-open-dkms"
  elif pacman -Q nvidia >> "${LOG_FILE}" 2>&1; then
    current_driver="nvidia"
  elif pacman -Q nvidia-open >> "${LOG_FILE}" 2>&1; then
    current_driver="nvidia-open"
  elif pacman -Q nvidia-470xx-dkms >> "${LOG_FILE}" 2>&1; then
    current_driver="nvidia-470xx-dkms"
  elif pacman -Q nvidia-390xx-dkms >> "${LOG_FILE}" 2>&1; then
    current_driver="nvidia-390xx-dkms"
  fi

  if [[ -n "${current_driver}" ]]; then
    menu_labels+=("Keep current NVIDIA driver config (${current_driver})")
    menu_values+=("${current_driver}")
  fi

  menu_labels+=("Skip NVIDIA driver changes")
  menu_values+=("")

  if [[ -n "${recommended}" ]]; then
    menu_labels+=("Recommended for detected GPU (${family}): ${recommended}")
    menu_values+=("${recommended}")
  fi

  menu_labels+=("nvidia-dkms (proprietary, broad kernel support)")
  menu_values+=("nvidia-dkms")
  menu_labels+=("nvidia-open-dkms (open kernel module)")
  menu_values+=("nvidia-open-dkms")
  menu_labels+=("nvidia (prebuilt for standard kernel)")
  menu_values+=("nvidia")
  menu_labels+=("nvidia-open (prebuilt open kernel module)")
  menu_values+=("nvidia-open")
  menu_labels+=("nvidia-470xx-dkms (legacy branch)")
  menu_values+=("nvidia-470xx-dkms")
  menu_labels+=("nvidia-390xx-dkms (older legacy branch)")
  menu_values+=("nvidia-390xx-dkms")

  printf "\n"
  printf "${BLUE}${BOLD}NVIDIA Driver Selection${NC}\n"
  printf "Detected NVIDIA GPU: %s\n" "${nvidia_name}"
  if [[ -n "${recommended}" ]]; then
    printf "Architecture family: %s (recommended: %s)\n" "${family}" "${recommended}"
  else
    printf "Architecture family: unknown (manual selection recommended)\n"
  fi
  printf "\n"

  local i=1
  for label in "${menu_labels[@]}"; do
    printf "  %d) %s\n" "${i}" "${label}"
    ((i++)) || true
  done
  printf "\n"

  menu_max=${#menu_values[@]}
  default_reply=1
  if [[ -z "${current_driver}" ]] && [[ -n "${recommended}" ]]; then
    default_reply=2
  fi
  read -r -p "Choose NVIDIA driver option (1-${menu_max}) [default: ${default_reply}]: " reply < /dev/tty

  if [[ -z "${reply}" ]]; then
    reply="${default_reply}"
  fi

  if [[ ! "${reply}" =~ ^[0-9]+$ ]] || (( reply < 1 || reply > menu_max )); then
    warn "Invalid NVIDIA driver selection. Skipping NVIDIA driver changes."
    SELECTED_NVIDIA_DRIVER_PACKAGE=""
    return 0
  fi

  SELECTED_NVIDIA_DRIVER_PACKAGE="${menu_values[$((reply - 1))]}"

  if [[ -n "${SELECTED_NVIDIA_DRIVER_PACKAGE}" ]]; then
    add_nvidia_driver_bundle "${SELECTED_NVIDIA_DRIVER_PACKAGE}"
    msg "Selected NVIDIA driver package: ${SELECTED_NVIDIA_DRIVER_PACKAGE}"
  else
    info "Skipping NVIDIA driver package changes."
  fi
}

select_intel_driver_bundle() {
  local reply current_intel_profile default_reply

  current_intel_profile=""
  if pacman -Q mesa >> "${LOG_FILE}" 2>&1 &&
    pacman -Q vulkan-intel >> "${LOG_FILE}" 2>&1 &&
    pacman -Q intel-media-driver >> "${LOG_FILE}" 2>&1; then
    current_intel_profile="recommended"
  elif pacman -Q mesa >> "${LOG_FILE}" 2>&1 &&
    pacman -Q vulkan-intel >> "${LOG_FILE}" 2>&1 &&
    pacman -Q libva-intel-driver >> "${LOG_FILE}" 2>&1; then
    current_intel_profile="compat"
  fi

  printf "\n"
  printf "${BLUE}${BOLD}Intel Driver Selection${NC}\n"
  local option=1
  declare -A intel_options=()
  if [[ -n "${current_intel_profile}" ]]; then
    if [[ "${current_intel_profile}" == "recommended" ]]; then
      printf "  %d) Keep current Intel driver config (mesa + vulkan-intel + intel-media-driver)\n" "${option}"
    else
      printf "  %d) Keep current Intel driver config (mesa + vulkan-intel + libva-intel-driver)\n" "${option}"
    fi
    intel_options[${option}]="${current_intel_profile}"
    ((option++)) || true
  fi
  printf "  %d) Skip Intel driver package changes\n" "${option}"
  intel_options[${option}]="skip"
  ((option++)) || true
  printf "  %d) Recommended: mesa + vulkan-intel + intel-media-driver\n" "${option}"
  intel_options[${option}]="recommended"
  ((option++)) || true
  printf "  %d) Compatibility: mesa + vulkan-intel + libva-intel-driver\n" "${option}"
  intel_options[${option}]="compat"
  printf "\n"

  default_reply=1
  if [[ -z "${current_intel_profile}" ]]; then
    default_reply=2
  fi
  read -r -p "Choose Intel driver option (1-$((option - 1))) [default: ${default_reply}]: " reply < /dev/tty
  if [[ -z "${reply}" ]]; then
    reply="${default_reply}"
  fi

  case "${intel_options[${reply}]:-skip}" in
    recommended)
      SELECTED_INTEL_DRIVER_PROFILE="recommended"
      add_optional_package "mesa"
      add_optional_package "vulkan-intel"
      add_optional_package "intel-media-driver"
      msg "Selected Intel driver bundle: mesa + vulkan-intel + intel-media-driver"
      ;;
    compat)
      SELECTED_INTEL_DRIVER_PROFILE="compat"
      add_optional_package "mesa"
      add_optional_package "vulkan-intel"
      add_optional_package "libva-intel-driver"
      msg "Selected Intel driver bundle: mesa + vulkan-intel + libva-intel-driver"
      ;;
    *)
      SELECTED_INTEL_DRIVER_PROFILE="skip"
      info "Skipping Intel driver package changes."
      ;;
  esac
}

select_amd_driver_bundle() {
  local reply current_amd_profile default_reply

  current_amd_profile=""
  if pacman -Q mesa >> "${LOG_FILE}" 2>&1 &&
    pacman -Q vulkan-radeon >> "${LOG_FILE}" 2>&1 &&
    pacman -Q libva-mesa-driver >> "${LOG_FILE}" 2>&1; then
    current_amd_profile="recommended"
  elif pacman -Q mesa >> "${LOG_FILE}" 2>&1; then
    current_amd_profile="minimal"
  fi

  printf "\n"
  printf "${BLUE}${BOLD}AMD Driver Selection${NC}\n"
  local option=1
  declare -A amd_options=()
  if [[ -n "${current_amd_profile}" ]]; then
    if [[ "${current_amd_profile}" == "recommended" ]]; then
      printf "  %d) Keep current AMD driver config (mesa + vulkan-radeon + libva-mesa-driver)\n" "${option}"
    else
      printf "  %d) Keep current AMD driver config (mesa only)\n" "${option}"
    fi
    amd_options[${option}]="${current_amd_profile}"
    ((option++)) || true
  fi
  printf "  %d) Skip AMD driver package changes\n" "${option}"
  amd_options[${option}]="skip"
  ((option++)) || true
  printf "  %d) Recommended: mesa + vulkan-radeon + libva-mesa-driver\n" "${option}"
  amd_options[${option}]="recommended"
  ((option++)) || true
  printf "  %d) Minimal: mesa only\n" "${option}"
  amd_options[${option}]="minimal"
  printf "\n"

  default_reply=1
  if [[ -z "${current_amd_profile}" ]]; then
    default_reply=2
  fi
  read -r -p "Choose AMD driver option (1-$((option - 1))) [default: ${default_reply}]: " reply < /dev/tty
  if [[ -z "${reply}" ]]; then
    reply="${default_reply}"
  fi

  case "${amd_options[${reply}]:-skip}" in
    recommended)
      SELECTED_AMD_DRIVER_PROFILE="recommended"
      add_optional_package "mesa"
      add_optional_package "vulkan-radeon"
      add_optional_package "libva-mesa-driver"
      msg "Selected AMD driver bundle: mesa + vulkan-radeon + libva-mesa-driver"
      ;;
    minimal)
      SELECTED_AMD_DRIVER_PROFILE="minimal"
      add_optional_package "mesa"
      msg "Selected AMD driver bundle: mesa only"
      ;;
    *)
      SELECTED_AMD_DRIVER_PROFILE="skip"
      info "Skipping AMD driver package changes."
      ;;
  esac
}

configure_gpu_driver_selection() {
  local intel_line amd_line nvidia_line reply

  if ! command -v lspci >/dev/null 2>&1; then
    warn "lspci is not available; skipping GPU-specific driver/session setup."
    SELECTED_GPU_SESSION_MODE="auto"
    return 0
  fi

  if [[ "${REPAIR_MODE}" == "true" ]] && [[ "${INSTALL_PROFILE_LOADED}" == "true" ]]; then
    info "Repair mode: reusing saved GPU session and driver selections."
    case "${SELECTED_INTEL_DRIVER_PROFILE:-}" in
      recommended)
        add_optional_package "mesa"
        add_optional_package "vulkan-intel"
        add_optional_package "intel-media-driver"
        ;;
      compat)
        add_optional_package "mesa"
        add_optional_package "vulkan-intel"
        add_optional_package "libva-intel-driver"
        ;;
    esac
    case "${SELECTED_AMD_DRIVER_PROFILE:-}" in
      recommended)
        add_optional_package "mesa"
        add_optional_package "vulkan-radeon"
        add_optional_package "libva-mesa-driver"
        ;;
      minimal)
        add_optional_package "mesa"
        ;;
    esac
    if [[ -n "${SELECTED_NVIDIA_DRIVER_PACKAGE}" ]]; then
      add_nvidia_driver_bundle "${SELECTED_NVIDIA_DRIVER_PACKAGE}"
    fi
    add_summary "GPU mode (reused): ${SELECTED_GPU_SESSION_MODE}"
    if [[ -n "${SELECTED_INTEL_DRIVER_PROFILE:-}" ]]; then
      add_summary "Intel driver profile (reused): ${SELECTED_INTEL_DRIVER_PROFILE}"
    fi
    if [[ -n "${SELECTED_AMD_DRIVER_PROFILE:-}" ]]; then
      add_summary "AMD driver profile (reused): ${SELECTED_AMD_DRIVER_PROFILE}"
    fi
    if [[ -n "${SELECTED_NVIDIA_DRIVER_PACKAGE}" ]]; then
      add_summary "NVIDIA driver selected (reused): ${SELECTED_NVIDIA_DRIVER_PACKAGE}"
    fi
    return 0
  fi

  intel_line="$(lspci -nn | grep -Ei 'VGA|3D|Display' | grep -Ei 'Intel' | head -n 1 || true)"
  amd_line="$(lspci -nn | grep -Ei 'VGA|3D|Display' | grep -Ei 'AMD|Advanced Micro Devices|ATI' | head -n 1 || true)"
  nvidia_line="$(lspci -nn | grep -Ei 'VGA|3D|Display' | grep -Ei 'NVIDIA' | head -n 1 || true)"

  DETECTED_GPU_INTEL_NAME=""
  DETECTED_GPU_AMD_NAME=""
  DETECTED_GPU_NVIDIA_NAME=""
  SELECTED_INTEL_DRIVER_PROFILE="skip"
  SELECTED_AMD_DRIVER_PROFILE="skip"
  SELECTED_NVIDIA_DRIVER_PACKAGE=""

  if [[ -n "${intel_line}" ]]; then
    DETECTED_GPU_INTEL_NAME="$(printf '%s' "${intel_line}" | sed -E 's/.*: (.*) \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\].*/\1/')"
  fi
  if [[ -n "${amd_line}" ]]; then
    DETECTED_GPU_AMD_NAME="$(printf '%s' "${amd_line}" | sed -E 's/.*: (.*) \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\].*/\1/')"
  fi
  if [[ -n "${nvidia_line}" ]]; then
    DETECTED_GPU_NVIDIA_NAME="$(printf '%s' "${nvidia_line}" | sed -E 's/.*: (.*) \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\].*/\1/')"
  fi

  printf "\n"
  printf "${BLUE}${BOLD}GPU Detection${NC}\n"
  if [[ -n "${DETECTED_GPU_INTEL_NAME}" ]]; then
    printf "  - Intel:   %s\n" "${DETECTED_GPU_INTEL_NAME}"
  fi
  if [[ -n "${DETECTED_GPU_AMD_NAME}" ]]; then
    printf "  - AMD:     %s\n" "${DETECTED_GPU_AMD_NAME}"
  fi
  if [[ -n "${DETECTED_GPU_NVIDIA_NAME}" ]]; then
    printf "  - NVIDIA:  %s\n" "${DETECTED_GPU_NVIDIA_NAME}"
  fi
  if [[ -z "${DETECTED_GPU_INTEL_NAME}" ]] && [[ -z "${DETECTED_GPU_AMD_NAME}" ]] && [[ -z "${DETECTED_GPU_NVIDIA_NAME}" ]]; then
    warn "No supported GPU detected from lspci output. Keeping automatic mode."
    SELECTED_GPU_SESSION_MODE="auto"
    return 0
  fi
  printf "\n"

  printf "${BLUE}${BOLD}Niri Session GPU Mode${NC}\n"
  local option=1
  local -A gpu_mode_options=()
  printf "  %d) auto (default)\n" "${option}"
  gpu_mode_options[${option}]="auto"
  ((option++)) || true

  if [[ -n "${DETECTED_GPU_INTEL_NAME}" ]]; then
    printf "  %d) intel\n" "${option}"
    gpu_mode_options[${option}]="intel"
    ((option++)) || true
  fi

  if [[ -n "${DETECTED_GPU_NVIDIA_NAME}" ]]; then
    printf "  %d) nvidia\n" "${option}"
    gpu_mode_options[${option}]="nvidia"
    ((option++)) || true
  fi

  if [[ -n "${DETECTED_GPU_AMD_NAME}" ]]; then
    printf "  %d) amd\n" "${option}"
    gpu_mode_options[${option}]="amd"
    ((option++)) || true
  fi

  printf "\n"
  read -r -p "Choose default GPU mode for SDDM Niri sessions [default: 1]: " reply < /dev/tty

  if [[ -z "${reply}" ]]; then
    reply="1"
  fi

  SELECTED_GPU_SESSION_MODE="${gpu_mode_options[${reply}]:-auto}"

  if [[ -n "${DETECTED_GPU_INTEL_NAME}" ]]; then
    select_intel_driver_bundle
  fi

  if [[ -n "${DETECTED_GPU_AMD_NAME}" ]]; then
    select_amd_driver_bundle
  fi

  if [[ -n "${DETECTED_GPU_NVIDIA_NAME}" ]]; then
    select_nvidia_driver "${DETECTED_GPU_NVIDIA_NAME}"
  fi

  add_summary "GPU mode: ${SELECTED_GPU_SESSION_MODE}"
  if [[ -n "${DETECTED_GPU_INTEL_NAME}" ]]; then
    add_summary "Intel driver profile: ${SELECTED_INTEL_DRIVER_PROFILE}"
  fi
  if [[ -n "${DETECTED_GPU_AMD_NAME}" ]]; then
    add_summary "AMD driver profile: ${SELECTED_AMD_DRIVER_PROFILE}"
  fi
  if [[ -n "${SELECTED_NVIDIA_DRIVER_PACKAGE}" ]]; then
    add_summary "NVIDIA driver selected: ${SELECTED_NVIDIA_DRIVER_PACKAGE}"
  fi
}
