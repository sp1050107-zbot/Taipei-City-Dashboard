#!/usr/bin/env bash
# Phase 2 hybrid dev: generate the FE local env file for native `npm run dev`
# from the developer's own Mapbox key file. Never overwrites an existing file
# and never prints the token.
#
# Usage: make-dev-env.sh [KEY_FILE]
#   KEY_FILE defaults to <repo root>/mapbox-key.txt (or $MAPBOX_KEY_FILE).
#   Output defaults to .env.local in this directory (or $ENV_LOCAL_OUT).
set -euo pipefail
cd "$(dirname "$0")"

KEY_FILE="${1:-${MAPBOX_KEY_FILE:-../mapbox-key.txt}}"
OUT_FILE="${ENV_LOCAL_OUT:-.env.local}"

if [ -e "$OUT_FILE" ]; then
  echo "refusing to overwrite existing $OUT_FILE" >&2
  exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
  echo "missing key file: $KEY_FILE" >&2
  exit 1
fi

TOKEN="$(tr -d '[:space:]' < "$KEY_FILE")"
if [ -z "$TOKEN" ]; then
  echo "key file is empty: $KEY_FILE" >&2
  exit 1
fi

umask 077
cat > "$OUT_FILE" <<EOF
VITE_API_URL=/api/dev
VITE_APP_TITLE=臺北城市儀表板
VITE_APP_VERSION=2.0.0
VITE_MAPBOXTOKEN=${TOKEN}
VITE_MAPBOXTILE=
EOF
chmod 600 "$OUT_FILE"
echo "wrote $OUT_FILE"
