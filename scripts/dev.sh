#!/usr/bin/env bash
set -euo pipefail

readonly NOVNC_PORT="${ZCODE_NOVNC_PORT:-6180}"

case "$(id -u)" in
  0)
    echo "Refusing to run as root: this stack is meant to use your desktop user." >&2
    exit 1
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required." >&2
  exit 1
fi

if [[ ! -d "$HOME" ]]; then
  echo "HOME is not a directory: $HOME" >&2
  exit 1
fi

if [[ "$HOME" != /* ]]; then
  echo "HOME must be absolute: $HOME" >&2
  exit 1
fi

ZCODE_UID="$(id -u)"
ZCODE_GID="$(id -g)"
export ZCODE_UID ZCODE_GID
export ZCODE_HOME="$HOME"
export ZCODE_NOVNC_PORT="$NOVNC_PORT"

compose_args=(compose -f compose.yaml)
project=${ZCODE_COMPOSE_PROJECT_NAME:-zcode-browser}
export ZCODE_COMPOSE_PROJECT_NAME="$project"

if [[ "${1:-up}" == "up" ]]; then
  if ss -ltnH "sport = :$NOVNC_PORT" 2>/dev/null | grep -q .; then
    echo "Host port $NOVNC_PORT is already in use. Set ZCODE_NOVNC_PORT to another loopback port." >&2
    exit 1
  fi
  docker "${compose_args[@]}" up --build --detach
  docker "${compose_args[@]}" ps
  echo
  echo "Zcode browser desktop: http://127.0.0.1:$NOVNC_PORT/vnc.html?autoconnect=1&resize=scale"
  echo "This session can read and write all of $HOME."
else
  docker "${compose_args[@]}" "$@"
fi
