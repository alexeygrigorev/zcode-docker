#!/usr/bin/env bash
set -euo pipefail

readonly NOVNC_PORT="${ZCODE_NOVNC_PORT:-6180}"
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VERSION_FILE="$REPO_ROOT/.zcode-version"

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

# Resolve the ZCode release to build against: explicit env var, cached
# version file, or a best-effort fetch of the current manifest. The value
# keys the Docker cache, so it must stay stable between builds.
resolve_zcode_version() {
  if [[ -n "${ZCODE_VERSION:-}" ]]; then
    return
  fi
  local latest
  latest="$(bash "$REPO_ROOT/scripts/zcode-manifest-version.sh" 2>/dev/null || true)"
  if [[ -n "$latest" ]]; then
    printf '%s\n' "$latest" > "$VERSION_FILE"
    ZCODE_VERSION="$latest"
  elif [[ -s "$VERSION_FILE" ]]; then
    ZCODE_VERSION="$(<"$VERSION_FILE")"
  else
    ZCODE_VERSION=""
  fi
  export ZCODE_VERSION
}

command="${1:-up}"
case "$command" in
  update)
    latest="$(bash "$REPO_ROOT/scripts/zcode-manifest-version.sh")"
    if [[ -n "$latest" ]]; then
      printf '%s\n' "$latest" > "$VERSION_FILE"
    fi
    export ZCODE_VERSION="$latest"
    installed="$(docker image inspect -f '{{ index .Config.Labels "zcode.version" }}' zcode-browser:latest 2>/dev/null || true)"
    if [[ -n "$installed" && "$installed" == "$latest" ]]; then
      echo "ZCode $latest is already installed."
      exit 0
    fi
    docker "${compose_args[@]}" build
    echo
    echo "Image updated to ZCode $latest."
    echo "The running container was NOT restarted. When you are ready"
    echo "(this ends the current desktop session):"
    echo
    echo "  $0 restart"
    ;;
  restart)
    resolve_zcode_version
    docker "${compose_args[@]}" up --build --detach
    echo
    echo "Zcode browser desktop: http://127.0.0.1:$NOVNC_PORT/vnc.html?autoconnect=1&resize=scale"
    echo "ZCode version: ${ZCODE_VERSION:-unknown}"
    ;;
  up)
    resolve_zcode_version
    if ss -ltnH "sport = :$NOVNC_PORT" 2>/dev/null | grep -q .; then
      echo "Host port $NOVNC_PORT is already in use. Set ZCODE_NOVNC_PORT to another loopback port." >&2
      exit 1
    fi
    docker "${compose_args[@]}" up --build --detach
    docker "${compose_args[@]}" ps
    echo
    echo "Zcode browser desktop: http://127.0.0.1:$NOVNC_PORT/vnc.html?autoconnect=1&resize=scale"
    echo "ZCode version: ${ZCODE_VERSION:-unknown} (run '$0 update' to refresh)"
    echo "This session can read and write all of $HOME."
    ;;
  *)
    docker "${compose_args[@]}" "$@"
    ;;
esac
