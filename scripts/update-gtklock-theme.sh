#!/usr/bin/env bash

set -euo pipefail

readonly USER_HOME="${HOME}"
readonly WALLUST_COLORS="${USER_HOME}/.cache/wallust/colors.json"
readonly GTKLOCK_STYLE="${USER_HOME}/.config/gtklock/style.css"

if [[ ! -f "${WALLUST_COLORS}" ]]; then
  exit 1
fi

mkdir -p "$(dirname "${GTKLOCK_STYLE}")"

background="$(jq -r '.special.background' "${WALLUST_COLORS}")"
foreground="$(jq -r '.special.foreground' "${WALLUST_COLORS}")"
muted="$(jq -r '.colors.color7 // .special.foreground' "${WALLUST_COLORS}")"
accent="$(jq -r '.colors.color4 // .colors.color2 // .special.foreground' "${WALLUST_COLORS}")"
accent_hover="$(jq -r '.colors.color6 // .colors.color4 // .special.foreground' "${WALLUST_COLORS}")"
accent_active="$(jq -r '.colors.color5 // .colors.color6 // .special.foreground' "${WALLUST_COLORS}")"
surface="$(jq -r '.colors.color0 // .special.background' "${WALLUST_COLORS}")"
surface_border="$(jq -r '.colors.color8 // .special.foreground' "${WALLUST_COLORS}")"
darkest="${background}"

cat > "${GTKLOCK_STYLE}" <<EOF
window {
   background-size: cover;
   background-repeat: no-repeat;
   background-position: center;
   background-color: ${background};
}

#window-box {
   padding: 24px;
   spacing: 16px;
}

#auth-card {
   min-width: 392px;
   padding: 28px;
   border-radius: 20px;
   border: 2px solid ${darkest};
   background-color: alpha(${background}, 0.78);
   box-shadow: 0 18px 60px alpha(black, 0.35);
}

#info-box {
   margin-bottom: 2px;
}

#user-revealer {
   margin-top: 40px;
}

#user-box {
   spacing: 10px;
}

#user-image {
   border: 2px solid ${darkest};
   box-shadow: 0 12px 36px alpha(black, 0.25);
}

#user-name {
   color: ${foreground};
   font-family: "RedHatDisplay", "JetBrainsMono Nerd Font", sans-serif;
   font-size: 13pt;
   font-weight: 700;
}

#clock-label {
   color: ${foreground};
   font-family: "RedHatDisplay", "JetBrainsMono Nerd Font", sans-serif;
   font-size: 54pt;
   font-weight: 800;
}

#date-label {
   color: ${muted};
   font-family: "RedHatDisplay", "JetBrainsMono Nerd Font", sans-serif;
   font-size: 14pt;
   font-weight: 600;
}

#input-label,
#warning-label,
#error-label,
#message-box label {
   color: ${muted};
   font-family: "RedHatDisplay", "JetBrainsMono Nerd Font", sans-serif;
   font-size: 11pt;
}

#input-field {
   padding: 0 14px;
   border-radius: 10px;
   border-top: 1px solid ${surface_border};
   border-bottom: 1px solid ${surface_border};
   border-left: 1px solid ${surface_border};
   border-right: none;
   color: ${foreground};
   caret-color: ${foreground};
   background-color: alpha(${surface}, 0.72);
   box-shadow: none;
}

#input-field image {
   color: ${foreground};
}

#unlock-button {
   padding: 0 18px;
   border-radius: 10px;
   border: 1px solid ${darkest};
   background-image: none;
   background-color: ${accent};
   color: ${background};
   font-family: "RedHatDisplay", "JetBrainsMono Nerd Font", sans-serif;
   font-size: 11pt;
   font-weight: 700;
   box-shadow: none;
}

#unlock-button:hover,
#unlock-button:focus {
   background-color: ${accent_hover};
   color: ${background};
}

#unlock-button:active {
   background-color: ${accent_active};
}

#status-box {
   margin-top: 4px;
}

#warning-label {
   color: #f9e2af;
}

#error-label {
   color: #f38ba8;
}

#message-scrolled-window,
#message-scrolled-window viewport {
   background: transparent;
   border: none;
   box-shadow: none;
}
EOF
