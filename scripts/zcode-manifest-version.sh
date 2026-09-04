#!/usr/bin/env bash
# Print the current stable ZCode version from the official update manifest.
set -euo pipefail

endpoint="${ZCODE_ENDPOINT:-https://zcode.z.ai}"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) platform="linux-x86_64" ;;
  Linux-aarch64) platform="linux-aarch64" ;;
  *) echo "unsupported platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

curl --fail --location --silent --show-error \
  "$endpoint/api/v1/releases/electron/manifest?platform=$platform&channel=1" \
  | awk '!seen && $1 == "version:" { print $2; seen = 1 }'
