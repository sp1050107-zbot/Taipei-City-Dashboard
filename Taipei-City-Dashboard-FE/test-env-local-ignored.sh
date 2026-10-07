#!/usr/bin/env bash
# Asserts git ignores the FE local env file family (names only; no content, no tokens).
set -euo pipefail
cd "$(dirname "$0")/.."  # repo root, so git check-ignore sees the real .gitignore

fail=0
for f in \
  Taipei-City-Dashboard-FE/.env.local \
  Taipei-City-Dashboard-FE/.env.development.local \
  Taipei-City-Dashboard-FE/.env.production.local \
  Taipei-City-Dashboard-FE/.env.test.local; do
  git check-ignore -q "$f" || { echo "FAIL: $f is NOT gitignored"; fail=1; }
done

# Pre-existing env ignores must stay intact.
for f in \
  docker/.env \
  Taipei-City-Dashboard-FE/.env \
  Taipei-City-Dashboard-FE/.env.development \
  Taipei-City-Dashboard-FE/.env.production \
  Taipei-City-Dashboard-FE/.env.test; do
  git check-ignore -q "$f" || { echo "FAIL: existing entry $f no longer ignored"; fail=1; }
done

# Throwaway real file: must not show up as untracked.
tmp=Taipei-City-Dashboard-FE/.env.throwaway-test.local
trap 'rm -f "$tmp"' EXIT
: > "$tmp"
if git status --porcelain --untracked-files=all -- "$tmp" | grep -q .; then
  echo "FAIL: $tmp appears in git status"; fail=1
fi

[ "$fail" -eq 0 ] && echo "PASS"
exit "$fail"
