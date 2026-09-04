#!/usr/bin/env bash
set -euo pipefail

umask 077

readonly APP=/opt/ZCode/zcode
readonly DISPLAY_NUMBER="${DISPLAY#:}"
readonly RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
readonly VNC_BIND_ADDRESS="${VNC_BIND_ADDRESS:-127.0.0.1}"
readonly VNC_PORT="${VNC_PORT:-6080}"
readonly VNC_BACKEND_PORT="${VNC_BACKEND_PORT:-5900}"
uid="$(id -u)"
gid="$(id -g)"
export HOME=/home/zcode
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"

# ZCode opens OAuth URLs through xdg-open. Chrome handles those reliably in
# this container, while Epiphany's WebKit/bwrap sandbox does not.
if command -v xdg-settings >/dev/null 2>&1 && command -v google-chrome >/dev/null 2>&1; then
  xdg-settings set default-web-browser google-chrome.desktop >/dev/null 2>&1 || true
  xdg-mime default google-chrome.desktop x-scheme-handler/https >/dev/null 2>&1 || true
  xdg-mime default google-chrome.desktop x-scheme-handler/http >/dev/null 2>&1 || true
fi

mkdir -p \
  "$HOME" \
  "$XDG_CONFIG_HOME" \
  "$XDG_DATA_HOME" \
  "$XDG_CACHE_HOME" \
  "$XDG_STATE_HOME" \
  "$HOME/.fluxbox" \
  "$RUNTIME_DIR" \
  /tmp/.X11-unix

# Docker creates the runtime dir before applying the runtime UID. Correct both
# common mounts when the requested IDs differ.
if [[ "$(stat -c %u "$RUNTIME_DIR")" != "$uid" || "$(stat -c %g "$RUNTIME_DIR")" != "$gid" ]]; then
  chown "$uid:$gid" "$RUNTIME_DIR" 2>/dev/null || true
fi
chmod 0700 "$RUNTIME_DIR"

if [[ ! -e "$HOME/.fluxbox/menu" ]]; then
  install -m 0644 /usr/local/share/zcode-docker/fluxbox-menu "$HOME/.fluxbox/menu"
fi

# A killed container can leave ZCode's mkdir-based settings lock behind on the
# shared home mount. Every later settings write (recent projects, last open
# workspaces) then times out after ~8s, so newly opened projects are never
# persisted and the next restart restores only old projects. The lock is held
# only for the duration of an atomic file write (milliseconds), so a lock dir
# older than a few minutes is guaranteed stale and safe to drop.
ZCODE_SETTINGS_LOCK="$HOME/.zcode/v2/setting.json.lock"
if [[ -d "$ZCODE_SETTINGS_LOCK" ]] && [[ -z "$(find "$ZCODE_SETTINGS_LOCK" -maxdepth 0 -mmin -5 2>/dev/null)" ]]; then
  printf 'Removing stale ZCode settings lock: %s\n' "$ZCODE_SETTINGS_LOCK" >&2
  rm -rf "$ZCODE_SETTINGS_LOCK"
fi
unset ZCODE_SETTINGS_LOCK

export DBUS_SESSION_BUS_ADDRESS="unix:path=$RUNTIME_DIR/bus"
dbus-daemon --session --fork --address="$DBUS_SESSION_BUS_ADDRESS" --nopidfile

rm -f "/tmp/.X${DISPLAY_NUMBER}-lock" "/tmp/.X11-unix/X${DISPLAY_NUMBER}"
Xvfb "$DISPLAY" -screen 0 1600x900x24 -nolisten tcp -noreset >/tmp/xvfb.log 2>&1 &
xvfb_pid=$!

for _ in $(seq 1 100); do
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$xvfb_pid" 2>/dev/null; then
    printf 'Xvfb failed to start:\n' >&2
    sed -n '1,160p' /tmp/xvfb.log >&2
    exit 1
  fi
  sleep 0.1
done

fluxbox -display "$DISPLAY" >/tmp/fluxbox.log 2>&1 &

x11vnc \
  -display "$DISPLAY" \
  -noshm \
  -localhost \
  -rfbport "$VNC_BACKEND_PORT" \
  -forever \
  -shared \
  -nopw \
  -quiet >/tmp/x11vnc.log 2>&1 &

websockify --web=/usr/share/novnc "$VNC_BIND_ADDRESS:$VNC_PORT" "localhost:$VNC_BACKEND_PORT" >/tmp/websockify.log 2>&1 &

for _ in $(seq 1 100); do
  if curl --fail --silent http://127.0.0.1:"$VNC_PORT"/vnc.html >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

# The app is not sandboxed by Chromium because the container intentionally runs
# as an arbitrary host UID with no-new-privileges. Docker remains the boundary.
exec "$APP" --no-sandbox --password-store=basic "$@"
