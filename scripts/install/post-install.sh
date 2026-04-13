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
