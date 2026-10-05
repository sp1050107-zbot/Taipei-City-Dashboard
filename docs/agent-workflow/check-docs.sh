#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

for f in CLAUDE.md AGENTS.md MEMORY.md; do [ -f "$f" ] || fail "$f missing"; done
[ "$(wc -l < CLAUDE.md)" -le 100 ] || fail "CLAUDE.md exceeds 100 lines"
grep -q '^@AGENTS.md' CLAUDE.md || fail "CLAUDE.md must import @AGENTS.md"

# every markdown link target in MEMORY.md must exist
while IFS= read -r target; do
  [ -e "$target" ] || fail "MEMORY.md links to missing path: $target"
done < <(grep -oE '\]\(([^)#]+)' MEMORY.md | sed 's/](//' | grep -v '^http' || true)

# no secrets in the trio
if grep -nE 'pk\.[A-Za-z0-9._-]{20,}|sk-[A-Za-z0-9]{20,}' CLAUDE.md AGENTS.md MEMORY.md >/dev/null; then
  fail "possible secret found in docs trio"
fi
echo PASS
