#!/usr/bin/env bash
# Tests make-dev-env.sh using ONLY a throwaway fake key file in a temp dir.
# Never touches the real mapbox-key.txt.
set -uo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
SENTINEL="pk.FAKESENTINELNOTAREALKEY12345"
KEY="$WORK/fake-key.txt"
OUT="$WORK/out.env.local"
echo "$SENTINEL" > "$KEY"
fail=0
bad() { echo "FAIL: $1"; fail=1; }

# 1. happy path: writes file, token present, mode 600, token not on stdout/stderr
MAPBOX_KEY_FILE="$KEY" ENV_LOCAL_OUT="$OUT" ./make-dev-env.sh >"$WORK/o1" 2>"$WORK/e1" || bad "generator failed on happy path"
grep -qx "VITE_MAPBOXTOKEN=$SENTINEL" "$OUT" || bad "token not written correctly"
PERM="$(stat -f '%Lp' "$OUT" 2>/dev/null || stat -c '%a' "$OUT")"
[ "$PERM" = "600" ] || bad "expected mode 600, got $PERM"
grep -q "$SENTINEL" "$WORK/o1" "$WORK/e1" && bad "token leaked to stdout/stderr (happy path)"

# 2. refuses to overwrite; existing content preserved; no token output
echo "PRECIOUS" > "$OUT"
MAPBOX_KEY_FILE="$KEY" ENV_LOCAL_OUT="$OUT" ./make-dev-env.sh >"$WORK/o2" 2>"$WORK/e2" && bad "should refuse to overwrite existing file"
[ "$(cat "$OUT")" = "PRECIOUS" ] || bad "existing file was modified"
grep -q "$SENTINEL" "$WORK/o2" "$WORK/e2" && bad "token leaked to stdout/stderr (refusal path)"

# 3. missing key file fails, creates nothing
rm -f "$OUT"
MAPBOX_KEY_FILE="$WORK/nope.txt" ENV_LOCAL_OUT="$OUT" ./make-dev-env.sh >/dev/null 2>&1 && bad "should fail on missing key file"
[ -e "$OUT" ] && bad "output created despite missing key"

# 4. empty key file fails, creates nothing
: > "$WORK/empty.txt"
MAPBOX_KEY_FILE="$WORK/empty.txt" ENV_LOCAL_OUT="$OUT" ./make-dev-env.sh >/dev/null 2>&1 && bad "should fail on empty key file"
[ -e "$OUT" ] && bad "output created despite empty key"

# 5. symlink at the output path is refused (dangling and to an existing file)
rm -f "$OUT"
ln -s "$WORK/victim-new" "$OUT"
MAPBOX_KEY_FILE="$KEY" ENV_LOCAL_OUT="$OUT" ./make-dev-env.sh >"$WORK/o5" 2>"$WORK/e5" && bad "should refuse dangling symlink"
[ -e "$WORK/victim-new" ] && bad "dangling symlink target was created"
grep -q "$SENTINEL" "$WORK/o5" "$WORK/e5" && bad "token leaked (dangling symlink path)"
rm -f "$OUT"
echo "PRECIOUS" > "$WORK/victim-old"
ln -s "$WORK/victim-old" "$OUT"
MAPBOX_KEY_FILE="$KEY" ENV_LOCAL_OUT="$OUT" ./make-dev-env.sh >/dev/null 2>&1 && bad "should refuse symlink to existing file"
[ "$(cat "$WORK/victim-old")" = "PRECIOUS" ] || bad "symlink target was modified"
rm -f "$OUT"

[ "$fail" -eq 0 ] && echo "PASS"
exit "$fail"
