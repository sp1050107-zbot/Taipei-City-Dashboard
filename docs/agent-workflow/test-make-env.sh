#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SENTINEL="pk.TESTSENTINEL0123456789"
printf '%s\n  \n' "$SENTINEL" > "$TMP/token.txt"     # trailing newline + whitespace line
fail(){ echo "FAIL: $*" >&2; exit 1; }

# 1. generates file, mode 600, token injected (whitespace stripped), nothing leaked
OUT="$(ENV_OUT="$TMP/.env" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" 2>&1)" || fail "make-env.sh failed on a valid run: $OUT"
[ -f "$TMP/.env" ] || fail "env file not created"
MODE="$(stat -c %a "$TMP/.env" 2>/dev/null || stat -f %Lp "$TMP/.env")"
[ "$MODE" = "600" ] || fail "mode is $MODE, want 600"
grep -qx "VITE_MAPBOXTOKEN=$SENTINEL" "$TMP/.env" || fail "token not injected exactly"
if printf '%s' "$OUT" | grep -q "$SENTINEL"; then fail "token leaked to output"; fi

# 2. required secrets are non-empty and not leaked
for k in JWT_SECRET IDNO_SALT DB_DASHBOARD_PASSWORD DB_MANAGER_PASSWORD DASHBOARD_DEFAULT_PASSWORD PGADMIN_DEFAULT_PASSWORD QDRANT_API_KEY; do
  v="$(grep "^$k=" "$TMP/.env" | cut -d= -f2-)"
  [ -n "$v" ] || fail "$k empty"
  if printf '%s' "$OUT" | grep -q "$v"; then fail "$k value leaked"; fi
done

# 3. refuses to overwrite
if ENV_OUT="$TMP/.env" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" >/dev/null 2>&1; then fail "overwrote existing env"; fi

# 4. missing token file: still generates, warns about mapbox, token empty
ENV_OUT="$TMP/.env2" TOKEN_FILE="$TMP/none.txt" "$HERE/make-env.sh" >/dev/null 2>"$TMP/err" || fail "missing token must not fail"
grep -qx 'VITE_MAPBOXTOKEN=' "$TMP/.env2" || fail "token should be empty"
grep -qi 'mapbox' "$TMP/err" || fail "no mapbox warning"

# 5. empty token file behaves like missing
: > "$TMP/empty.txt"
ENV_OUT="$TMP/.env3" TOKEN_FILE="$TMP/empty.txt" "$HERE/make-env.sh" >/dev/null 2>"$TMP/err3" || fail "empty token must not fail"
grep -qi 'mapbox' "$TMP/err3" || fail "no mapbox warning for empty file"

# 6. secrets differ between runs
a="$(grep '^JWT_SECRET=' "$TMP/.env")"; b="$(grep '^JWT_SECRET=' "$TMP/.env2")"
[ "$a" != "$b" ] || fail "secrets not random"

# 7. fails loudly (and creates nothing) when the template lacks expected keys
printf 'FOO=bar\n' > "$TMP/bad.template"
if TEMPLATE="$TMP/bad.template" ENV_OUT="$TMP/.env4" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" >/dev/null 2>"$TMP/err4"; then fail "must fail when template lacks expected keys"; fi
grep -q 'JWT_SECRET' "$TMP/err4" || fail "error must name the missing key"
[ ! -e "$TMP/.env4" ] || fail "must not create env file when keys are missing"

# 9. a pre-existing (even dangling) symlink at the target is refused with a clean message, not a traceback
ln -s "$TMP/does-not-exist" "$TMP/dangling"
if ENV_OUT="$TMP/dangling" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" >/dev/null 2>"$TMP/err6"; then fail "must refuse a symlink target"; fi
if grep -q 'Traceback' "$TMP/err6"; then fail "symlink target produced a Python traceback"; fi
grep -qi 'refusing' "$TMP/err6" || fail "symlink target must be refused with a clear message"

# 8. the real upstream template contains every expected key
ENV_OUT="$TMP/.env5" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" >/dev/null 2>&1 || fail "real docker/.env.template lacks an expected key"
echo PASS
