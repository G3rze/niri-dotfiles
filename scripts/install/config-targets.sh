detect_music_directory() {
  local music_dir=""

  if command -v xdg-user-dir &> /dev/null; then
    music_dir="$(xdg-user-dir MUSIC 2> /dev/null || true)"
  fi

  if [[ -z "${music_dir}" ]] || [[ "${music_dir}" == "${HOME}" ]]; then
    music_dir="${HOME}/Music"
  fi

  printf '%s\n' "${music_dir}"
}

link_entry() {
  local source_path="$1"
  local target_path="$2"

  if ln -s "${source_path}" "${target_path}" 2>> "${LOG_FILE}"; then
    info "Linked: ${target_path#"${CONFIG_DIR}/"}"
    return 0
  fi

  error "Failed to link: ${target_path#"${CONFIG_DIR}/"} (check log for details)"
  return 1
}

setup_fish_config() {
  local source_dir="${DOTDIR}/fish"
  local target_dir="${CONFIG_DIR}/fish"

  mkdir -p "${target_dir}"
  link_entry "${source_dir}/config.fish" "${target_dir}/config.fish"

  if [[ -d "${source_dir}/conf.d" ]]; then
    link_entry "${source_dir}/conf.d" "${target_dir}/conf.d"
  fi

  if [[ -d "${source_dir}/functions" ]]; then
    link_entry "${source_dir}/functions" "${target_dir}/functions"
  fi

  if [[ -d "${source_dir}/completions" ]]; then
    link_entry "${source_dir}/completions" "${target_dir}/completions"
  fi

  info "Preserved local fish universal variables by not linking fish_variables."
}

setup_anytype_config() {
  local source_dir="${DOTDIR}/anytype"
  local target_dir="${CONFIG_DIR}/anytype"

  mkdir -p "${target_dir}"

  if [[ -f "${source_dir}/devconfig.json" ]]; then
    link_entry "${source_dir}/devconfig.json" "${target_dir}/devconfig.json"
  fi

  info "Created local anytype config directory for runtime state."
}

setup_mpd_config_dir() {
  local target_dir="${CONFIG_DIR}/mpd"

  mkdir -p "${target_dir}/playlists"
  touch "${target_dir}/database" "${target_dir}/mpd.log" "${target_dir}/mpd.state" "${target_dir}/sticker.sql"
  info "Created local mpd config directory for runtime state."
}

create_symlinks() {
  msg "Creating symbolic links to ~/.config..."
  local linked=0
  local skipped=0

  for folder in "${CONFIG_FOLDERS[@]}"; do
    local source_dir="${DOTDIR}/${folder}"
    local target="${CONFIG_DIR}/${folder}"

    if [[ ! -d "${source_dir}" ]]; then
      info "Skipping: ${folder} (not found in repository)"
      ((++skipped)) || true
      continue
    fi

    if [[ -z "${CONFIG_DIR}" ]] || [[ -z "${target}" ]]; then
      fatal "Path validation failed: CONFIG_DIR or target is empty"
    fi

    if [[ -e "${target}" ]] || [[ -L "${target}" ]]; then
      warn "Target still exists: ${folder} (removing)"
      rm -rf "${target}"
    fi

    case "${folder}" in
      fish)
        setup_fish_config
        ((++linked)) || true
        ;;
      anytype)
        setup_anytype_config
        ((++linked)) || true
        ;;
      mpd)
        setup_mpd_config_dir
        ((++linked)) || true
        ;;
      *)
        if link_entry "${source_dir}" "${target}"; then
          ((++linked)) || true
        fi
        ;;
    esac
  done

  msg "Created ${linked} config target(s), skipped ${skipped}."
}

configure_mpd() {
  local mpd_dir="${CONFIG_DIR}/mpd"
  local music_dir
  music_dir="$(detect_music_directory)"

  mkdir -p "${mpd_dir}/playlists"
  mkdir -p "${music_dir}"
  touch "${mpd_dir}/database" "${mpd_dir}/mpd.log" "${mpd_dir}/mpd.state" "${mpd_dir}/sticker.sql"

  cat > "${mpd_dir}/mpd.conf" << EOF
music_directory "${music_dir}"
playlist_directory "${mpd_dir}/playlists"
db_file "${mpd_dir}/database"
log_file "${mpd_dir}/mpd.log"
pid_file "${mpd_dir}/mpd.pid"
state_file "${mpd_dir}/mpd.state"
sticker_file "${mpd_dir}/sticker.sql"

audio_output {
    type "pipewire"
    name "MPD Pipewire Output"
}

follow_outside_symlinks "yes"
follow_inside_symlinks "yes"
EOF

  add_summary "MPD config overwritten with music directory: ${music_dir}"
  msg "Configured MPD music directory: ${music_dir}"
}
