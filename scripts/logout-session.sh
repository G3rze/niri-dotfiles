#!/usr/bin/env bash

set -euo pipefail

session_id="${XDG_SESSION_ID:-}"

if [[ -z "${session_id}" ]]; then
  session_id="$(loginctl | awk -v user="${USER}" '$3 == user { print $1; exit }')"
fi

if [[ -z "${session_id}" ]]; then
  printf 'Could not determine the current session id.\n' >&2
  exit 1
fi

exec loginctl terminate-session "${session_id}"
