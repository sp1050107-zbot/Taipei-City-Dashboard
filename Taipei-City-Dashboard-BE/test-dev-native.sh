#!/usr/bin/env bash
# Tests for dev-native.sh. Uses a throwaway fake env file and a stub `go`;
# never touches the real Docker env file and never starts the backend.
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

SENTINEL_JWT="FAKE-SENTINEL-JWT-7f3a91"
SENTINEL_PW="FAKE-SENTINEL-PW-c42d08"

cat > "$WORK/fixture.env" <<EOF
JWT_SECRET=$SENTINEL_JWT
DB_DASHBOARD_USER=postgres
DB_DASHBOARD_PASSWORD=$SENTINEL_PW
DB_DASHBOARD_DBNAME=dashboard
DB_DASHBOARD_HOST=postgres-data
DB_DASHBOARD_PORT=5432
DB_MANAGER_USER=postgres
DB_MANAGER_PASSWORD=$SENTINEL_PW
DB_MANAGER_DBNAME=dashboardmanager
DB_MANAGER_HOST=postgres-manager
REDIS_HOST=redis
QDRANT_URL=http://qdrant:6333
GIN_DOMAIN=0.0.0.0
LM_MODEL_PATH=/opt/lm_model/onnx-e5/
ORT_LIBRARY_PATH=/opt/onnxruntime/lib/libonnxruntime.so
EOF

# Hostile values: the launcher must treat the env file as data, never as code.
{
  echo '# a comment line'
  echo ''
  echo 'TRICKY_DOLLAR=pa$$word'
  printf 'TRICKY_SUBST=$(touch %s/MARKER_SUBST)\n' "$WORK"
  printf 'TRICKY_TICK=`touch %s/MARKER_TICK`\n' "$WORK"
  printf 'TRICKY_SEMI=a;touch %s/MARKER_SEMI;b\n' "$WORK"
  echo 'TRICKY_SPACE=hello   world  x'
  echo "TRICKY_DQ=\"double with 'single' inside\""
  echo "TRICKY_SQ='single with \$HOME and \"dq\"'"
  echo 'TRICKY_EQ=a=b=c'
  echo 'TRICKY_EMPTY='
  echo 'TRICKY_MISMATCH="open only'
  echo '1BAD=never'
  echo 'BAD KEY=never'
} >> "$WORK/fixture.env"
printf 'TRICKY_LAST=no-trailing-newline' >> "$WORK/fixture.env"

# Stub go: dumps its environment and arguments to files, prints nothing.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/go" <<EOF
#!/usr/bin/env bash
env > "$WORK/go.env"
printf '%s\n' "\$@" > "$WORK/go.args"
EOF
chmod +x "$WORK/bin/go"

# Port preflight hook: default is "nothing listens"; tests never open sockets.
printf '#!/usr/bin/env bash\nexit 1\n' > "$WORK/bin/port-free"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/port-busy"
chmod +x "$WORK/bin/port-free" "$WORK/bin/port-busy"
export DEV_NATIVE_PORT_CHECK="$WORK/bin/port-free"

# Fake library and model so the success path passes the presence checks.
mkdir -p "$WORK/lib" "$WORK/model"
: > "$WORK/lib/libonnxruntime.dylib"
: > "$WORK/model/model.onnx"

run() { # run <stdout-file> <stderr-file> [VAR=value ...]; returns launcher status
  local o=$1 e=$2; shift 2
  rm -f "$WORK/go.env" "$WORK/go.args"
  PATH="$WORK/bin:$PATH" DEV_NATIVE_ENV_FILE="$WORK/fixture.env" env "$@" \
    ./dev-native.sh >"$o" 2>"$e"
}

# 1. Success path: overrides exported, nothing else new.
run "$WORK/ok.out" "$WORK/ok.err" \
  ORT_LIBRARY_PATH="$WORK/lib/libonnxruntime.dylib" LM_MODEL_PATH="$WORK/model/" \
  || fail "launcher failed with library and model present"

[ -f "$WORK/go.env" ] || fail "stub go was never invoked"
grep -qx 'run' "$WORK/go.args" && grep -qx 'main.go' "$WORK/go.args" || fail "expected 'go run main.go'"

assert_env() { grep -qx "$1" "$WORK/go.env" || fail "expected env line [$1]"; }
assert_env "DB_DASHBOARD_HOST=localhost"
assert_env "DB_DASHBOARD_PORT=5433"
assert_env "DB_MANAGER_HOST=localhost"
assert_env "DB_MANAGER_PORT=5432"
assert_env "REDIS_HOST=localhost"
assert_env "REDIS_PORT=6379"
assert_env "QDRANT_URL=http://localhost:6333"
assert_env "GIN_DOMAIN=localhost"
assert_env "GIN_PORT=8088"
assert_env "GOTOOLCHAIN=local"
assert_env "ORT_LIBRARY_PATH=$WORK/lib/libonnxruntime.dylib"
assert_env "JWT_SECRET=$SENTINEL_JWT"

# Finding 3: values arrive unchanged; nothing in the file was executed.
assert_env 'TRICKY_DOLLAR=pa$$word'
assert_env "TRICKY_SUBST=\$(touch $WORK/MARKER_SUBST)"
assert_env "TRICKY_TICK=\`touch $WORK/MARKER_TICK\`"
assert_env "TRICKY_SEMI=a;touch $WORK/MARKER_SEMI;b"
assert_env 'TRICKY_SPACE=hello   world  x'
assert_env "TRICKY_DQ=double with 'single' inside"
assert_env 'TRICKY_SQ=single with $HOME and "dq"'
assert_env 'TRICKY_EQ=a=b=c'
assert_env 'TRICKY_EMPTY='
assert_env 'TRICKY_MISMATCH="open only'
assert_env 'TRICKY_LAST=no-trailing-newline'
for m in MARKER_SUBST MARKER_TICK MARKER_SEMI; do
  [ ! -e "$WORK/$m" ] || fail "env file content was executed ($m created)"
done
if grep -qE '^(1BAD|BAD KEY|BAD)=' "$WORK/go.env"; then fail "invalid key names must be skipped"; fi

# "Exactly the listed overrides and nothing else new": compare variable names
# against a baseline (inherited env + fixture, no launcher).
keys() { sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' | grep -vxE '_|PWD|OLDPWD|SHLVL|DEV_NATIVE_ENV_FILE|DEV_NATIVE_PORT_CHECK' | sort -u; }
BASE=$( { env; grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$WORK/fixture.env"; } | keys)
GOT=$(keys < "$WORK/go.env")
NEW=$(comm -13 <(echo "$BASE") <(echo "$GOT") | tr '\n' ' ')
ALLOWED="DB_MANAGER_PORT GIN_PORT GOTOOLCHAIN REDIS_PORT "
# DB_*_PORT/HOST, REDIS_HOST, QDRANT_URL, GIN_DOMAIN are overrides of fixture keys, so only the rest are "new".
[ "$NEW" = "$ALLOWED" ] || fail "unexpected new variables: [$NEW] (allowed [$ALLOWED])"

# 2. Secrets never reach stdout or stderr (success and failure paths).
if run "$WORK/miss.out" "$WORK/miss.err" \
  ORT_LIBRARY_PATH="$WORK/nope/libonnxruntime.dylib" LM_MODEL_PATH="$WORK/model/"; then
  fail "failure-path run unexpectedly succeeded"
fi
grep -q "not found" "$WORK/miss.err" || fail "failure-path run did not reach the missing-library check"
for f in ok.out ok.err miss.out miss.err; do
  if grep -qE "$SENTINEL_JWT|$SENTINEL_PW" "$WORK/$f"; then fail "secret leaked in $f"; fi
done

# 3. Missing library: clear message, non-zero, backend never started.
if run "$WORK/a.out" "$WORK/a.err" \
  ORT_LIBRARY_PATH="$WORK/nope/libonnxruntime.dylib" LM_MODEL_PATH="$WORK/model/"; then
  fail "launcher should fail when the library is missing"
fi
grep -q "ONNX Runtime library not found" "$WORK/a.err" || fail "missing-library message not clear"
grep -q "$WORK/nope/libonnxruntime.dylib" "$WORK/a.err" || fail "message should name the path"
[ ! -f "$WORK/go.env" ] || fail "go ran despite missing library"

# 4. Missing model: clear message, non-zero, backend never started.
if run "$WORK/b.out" "$WORK/b.err" \
  ORT_LIBRARY_PATH="$WORK/lib/libonnxruntime.dylib" LM_MODEL_PATH="$WORK/nomodel/"; then
  fail "launcher should fail when the model is missing"
fi
grep -q "embedding model not found" "$WORK/b.err" || fail "missing-model message not clear"
[ ! -f "$WORK/go.env" ] || fail "go ran despite missing model"

# 5. Missing env file: clear failure, no go.
if PATH="$WORK/bin:$PATH" DEV_NATIVE_ENV_FILE="$WORK/absent.env" ./dev-native.sh >/dev/null 2>"$WORK/c.err"; then
  fail "launcher should fail when the env file is missing"
fi
grep -q "missing" "$WORK/c.err" || fail "missing-env-file message not clear"

# 6. Defaults point at the locations ticket 05 produces (no dependency on it).
if run "$WORK/d.out" "$WORK/d.err" ORT_LIBRARY_PATH= LM_MODEL_PATH=; then
  if [ ! -f "$PWD/onnxruntime/lib/libonnxruntime.dylib" ]; then fail "default library check did not trigger"; fi
fi
unset_run() { # run with both vars truly unset
  rm -f "$WORK/go.env"
  PATH="$WORK/bin:$PATH" DEV_NATIVE_ENV_FILE="$WORK/fixture.env" \
    env -u ORT_LIBRARY_PATH -u LM_MODEL_PATH ./dev-native.sh >"$WORK/e.out" 2>"$WORK/e.err"
}
if [ ! -f "$PWD/onnxruntime/lib/libonnxruntime.dylib" ]; then
  unset_run && fail "should fail with default library absent"
  grep -q "$PWD/onnxruntime/lib/libonnxruntime.dylib" "$WORK/e.err" || fail "default library path wrong"
fi
grep -q 'lm_model/onnx-e5' dev-native.sh || fail "default model path should be lm_model/onnx-e5"

# 8. Error text must not cite a path that does not exist in the repo.
REPO_ROOT="$(git rev-parse --show-toplevel)"
for p in $(grep -E 'echo "dev-native' dev-native.sh | grep -oE '[A-Za-z0-9_./-]+/[A-Za-z0-9_.-]+\.(sh|md|template|py)'); do
  [ -e "$REPO_ROOT/$p" ] || [ -e "$p" ] || fail "error text cites a path that does not exist: $p"
done

# 9. Finding 2: the env file's LM_MODEL_PATH / ORT_LIBRARY_PATH never win; the
# caller's own values (tests 1, 3, 4) and the native defaults do.
if [ ! -f "$PWD/onnxruntime/lib/libonnxruntime.dylib" ]; then
  if run "$WORK/f.out" "$WORK/f.err" ORT_LIBRARY_PATH= LM_MODEL_PATH="$WORK/model/"; then fail "default library absent, should fail"; fi
  grep -q "$PWD/onnxruntime/lib/libonnxruntime.dylib" "$WORK/f.err" || fail "env file ORT_LIBRARY_PATH must not win over the native default"
fi
if [ ! -f "$PWD/lm_model/onnx-e5/model.onnx" ]; then
  if run "$WORK/g.out" "$WORK/g.err" ORT_LIBRARY_PATH="$WORK/lib/libonnxruntime.dylib" LM_MODEL_PATH=; then fail "default model absent, should fail"; fi
  grep -q "$PWD/lm_model/onnx-e5/model.onnx" "$WORK/g.err" || fail "env file LM_MODEL_PATH must not win over the native default"
fi


# 7. No container commands.
if grep -vE '^\s*#' dev-native.sh | grep -qE 'docker[ -]compose|docker +(run|compose|start|up)'; then
  fail "launcher must not run docker or docker compose"
fi

echo "PASS"
