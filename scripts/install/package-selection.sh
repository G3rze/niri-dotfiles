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
