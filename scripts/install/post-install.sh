install_dev_tools() {
  if [[ "${INSTALL_NVM}" == "false" ]] &&
    [[ "${INSTALL_NODE_LTS}" == "false" ]] &&
    [[ -z "${SELECTED_JAVA_PACKAGE}" ]] &&
    [[ "${INSTALL_CODEX_CLI}" == "false" ]]; then
    info "Skipping developer tools."
    return
  fi

  if [[ "${INSTALL_NVM}" == "true" ]]; then
    info "Installing nvm..."
    if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash >> "${LOG_FILE}" 2>&1; then
      add_summary "nvm installed"
    else
      warn "nvm install failed."
    fi
  fi

  export NVM_DIR="${HOME}/.nvm"
  if [[ "${INSTALL_NODE_LTS}" == "true" ]] && [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    # shellcheck disable=SC1090
    . "${NVM_DIR}/nvm.sh"
    info "Installing latest Node.js LTS via nvm..."
    if nvm install --lts >> "${LOG_FILE}" 2>&1; then
      add_summary "Node.js LTS installed (nvm)"
    else
      warn "Node.js LTS install failed."
    fi
  elif [[ "${INSTALL_NODE_LTS}" == "true" ]]; then
    warn "nvm not found after install; skipping Node.js LTS."
  fi

  if [[ -n "${SELECTED_JAVA_PACKAGE}" ]]; then
    info "Java will be installed with the selected package: ${SELECTED_JAVA_PACKAGE}"
  fi

  if [[ "${INSTALL_CODEX_CLI}" == "true" ]]; then
    if command -v npm >/dev/null 2>&1; then
      if npm i -g @openai/codex >> "${LOG_FILE}" 2>&1; then
        add_summary "OpenAI Codex CLI installed"
      else
        warn "Codex CLI install failed."
      fi
    else
      warn "npm not found; cannot install Codex CLI."
    fi
  fi
}

ensure_sdl_videodriver() {
  info "Persisting SDL_VIDEODRIVER for Wayland/X11 fallback..."
  mkdir -p "${USER_ENV_DIR}"

  cat > "${SDL_ENV_FILE}" << EOF
SDL_VIDEODRIVER=${SDL_VIDEODRIVER_VALUE}
EOF

  add_summary "SDL_VIDEODRIVER persisted in ${SDL_ENV_FILE}"
  msg "Configured SDL_VIDEODRIVER=${SDL_VIDEODRIVER_VALUE}"
}

detect_gpu_name_by_vendor() {
  local vendor_regex="$1"
  if ! command -v lspci >/dev/null 2>&1; then
    printf '\n'
    return 0
  fi
  lspci -nn | grep -Ei 'VGA|3D|Display' | grep -Ei "${vendor_regex}" | head -n 1 | sed -E 's/.*: (.*) \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\].*/\1/' || true
}

create_wayland_session_entry() {
  local file_name="$1"
  local session_name="$2"
  local session_mode="$3"
  local target_dir="$4"
  local wrapper="${HOME}/.config/scripts/niri-gpu-session.sh"
  local temp_file

  temp_file="$(mktemp)"
  cat > "${temp_file}" << EOF
[Desktop Entry]
Name=${session_name}
Comment=Niri session (${session_mode} GPU mode)
Exec=${wrapper} ${session_mode}
Type=Application
DesktopNames=niri
EOF

  sudo install -m 644 "${temp_file}" "${target_dir}/${file_name}"
  rm -f "${temp_file}"
}

install_gpu_session_entries() {
  local intel_name amd_name nvidia_name
  local sessions_dir="${WAYLAND_SESSIONS_DIR}"
  local wrapper="${HOME}/.config/scripts/niri-gpu-session.sh"

  if [[ ! -f "${wrapper}" ]]; then
    warn "GPU session wrapper not found at ${wrapper}. Skipping SDDM GPU entries."
    return 1
  fi

  chmod +x "${wrapper}" || true

  intel_name="${DETECTED_GPU_INTEL_NAME:-}"
  amd_name="${DETECTED_GPU_AMD_NAME:-}"
  nvidia_name="${DETECTED_GPU_NVIDIA_NAME:-}"

  if [[ -z "${intel_name}" ]]; then
    intel_name="$(detect_gpu_name_by_vendor 'Intel')"
  fi
  if [[ -z "${amd_name}" ]]; then
    amd_name="$(detect_gpu_name_by_vendor 'AMD|Advanced Micro Devices|ATI')"
  fi
  if [[ -z "${nvidia_name}" ]]; then
    nvidia_name="$(detect_gpu_name_by_vendor 'NVIDIA')"
  fi

  if ! sudo install -d -m 755 "${sessions_dir}" >> "${LOG_FILE}" 2>&1; then
    warn "Failed to create ${sessions_dir}. Skipping GPU-specific SDDM entries."
    return 1
  fi

  create_wayland_session_entry "niri-auto.desktop" "Niri-Auto" "auto" "${sessions_dir}"
  if [[ -n "${intel_name}" ]]; then
    create_wayland_session_entry "niri-intel.desktop" "Niri-Intel (${intel_name})" "intel" "${sessions_dir}"
  fi
  if [[ -n "${nvidia_name}" ]]; then
    create_wayland_session_entry "niri-nvidia.desktop" "Niri-NVIDIA (${nvidia_name})" "nvidia" "${sessions_dir}"
  fi
  if [[ -n "${amd_name}" ]]; then
    create_wayland_session_entry "niri-amd.desktop" "Niri-AMD (${amd_name})" "amd" "${sessions_dir}"
  fi

  add_summary "Installed SDDM GPU session entries in ${sessions_dir}"
  msg "Installed SDDM GPU session entries (auto/intel/nvidia/amd when detected)."
}

configure_docker_access() {
  if [[ "${INSTALL_DOCKER}" != "true" ]]; then
    info "Docker was not selected. Skipping Docker service setup."
    return
  fi

  if ! verify_binary docker; then
    warn "docker binary not found, skipping Docker service setup."
    return
  fi

  info "Enabling Docker service and socket..."
  if sudo systemctl enable --now docker.service docker.socket >> "${LOG_FILE}" 2>&1; then
    add_summary "Docker service and socket enabled"
  else
    warn "Failed to enable/start Docker service and socket."
  fi

  info "Ensuring docker group exists..."
  sudo groupadd -f docker >> "${LOG_FILE}" 2>&1 || true

  if id -nG "${USER}" | grep -qw docker; then
    info "User ${USER} is already in the docker group."
  else
    info "Adding ${USER} to docker group..."
    if sudo usermod -aG docker "${USER}" >> "${LOG_FILE}" 2>&1; then
      add_summary "User ${USER} added to docker group"
      warn "Log out and back in before using Docker without sudo."
    else
      warn "Failed to add ${USER} to docker group."
    fi
  fi
}
