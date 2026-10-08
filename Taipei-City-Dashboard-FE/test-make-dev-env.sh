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

# 6. only a public-scope Mapbox token (pk. prefix) is accepted; the rejected
# value is never printed and nothing is created
for bad_val in "sk.FAKESECRETSCOPENOTAREALKEY999" "FAKENOPREFIXNOTAREALKEY777" "xpk.FAKEPREFIXINSIDENOTAREAL555"; do
  rm -f "$OUT"
  echo "$bad_val" > "$WORK/bad-key.txt"
  MAPBOX_KEY_FILE="$WORK/bad-key.txt" ENV_LOCAL_OUT="$OUT" ./make-dev-env.sh >"$WORK/o6" 2>"$WORK/e6" && bad "should reject non-public token ($bad_val)"
  [ -e "$OUT" ] && bad "output created for non-public token"
  grep -q "$bad_val" "$WORK/o6" "$WORK/e6" && bad "rejected token value was printed"
  grep -q "pk\." "$WORK/e6" || bad "rejection message should name the pk. prefix"
done
rm -f "$OUT"

# 7. frontend build context: .dockerignore excludes local env files and
# node_modules, and excludes nothing the Dockerfile's COPY lines need
python3 - <<'PY' || bad ".dockerignore check failed"
import fnmatch, subprocess, sys
lines = [l.strip() for l in open(".dockerignore")] if __import__("os").path.exists(".dockerignore") else sys.exit("missing .dockerignore")
pats = [l for l in lines if l and not l.startswith("#")]
for want in (".env.local", ".env.*.local", "node_modules"):
    if want not in pats:
        sys.exit("missing .dockerignore entry: " + want)
if any(p.startswith("!") for p in pats):
    sys.exit("negations are not supported by this check")
needed = subprocess.check_output(["git", "ls-files", "."], text=True).split("\n")
needed = [n for n in needed if n]
assert "package.json" in needed and "package-lock.json" in needed and any(n.startswith("src/") for n in needed)
def excluded(path):
    parts = path.split("/")
    for i in range(1, len(parts) + 1):
        sub = "/".join(parts[:i])
        for p in pats:
            q = p.rstrip("/").lstrip("/")
            if fnmatch.fnmatch(sub, q) or fnmatch.fnmatch(parts[i-1], q):
                return p
    return None
for n in needed:
    p = excluded(n)
    if p:
        sys.exit("pattern %r excludes a needed build input: %s" % (p, n))
PY

[ "$fail" -eq 0 ] && echo "PASS"
exit "$fail"
