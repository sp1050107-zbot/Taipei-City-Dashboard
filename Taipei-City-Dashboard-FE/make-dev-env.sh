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

if [ -e "$OUT_FILE" ] || [ -L "$OUT_FILE" ]; then
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

# VITE_ variables are shipped to the browser, so only a public-scope Mapbox
# token (pk. prefix) may be written. The value is never printed.
case "$TOKEN" in
  pk.*) ;;
  *)
    echo "key file does not hold a public Mapbox token (it must start with pk.): $KEY_FILE" >&2
    exit 1 ;;
esac

umask 077
# noclobber makes the redirect an exclusive create (O_EXCL): it fails on an
# existing file and never follows a symlink, closing the check-then-write race.
set -o noclobber
cat > "$OUT_FILE" <<EOF
VITE_API_URL=/api/dev
VITE_APP_TITLE=臺北城市儀表板
VITE_APP_VERSION=2.0.0
VITE_MAPBOXTOKEN=${TOKEN}
VITE_MAPBOXTILE=
EOF
chmod 600 "$OUT_FILE"
echo "wrote $OUT_FILE"
