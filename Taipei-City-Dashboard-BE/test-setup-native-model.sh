#!/usr/bin/env bash
# Tests for setup-native-model.sh. Uses stub curl/docker and a fake archive:
# no network, no Docker, no real download.
set -euo pipefail
cd "$(dirname "$0")"
SRC="$(pwd)"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/pkg/onnxruntime-osx-arm64-1.23.2/lib"
echo fake > "$WORK/pkg/onnxruntime-osx-arm64-1.23.2/lib/libonnxruntime.dylib"
tar -czf "$WORK/fixture.tgz" -C "$WORK/pkg" onnxruntime-osx-arm64-1.23.2
FIXTURE_SHA="$(shasum -a 256 "$WORK/fixture.tgz" | cut -d' ' -f1)"

fresh() { # fresh <case>: empty sandbox with the script and stubs first on PATH
  D="$WORK/$1"; mkdir -p "$D/bin"
  cp "$SRC/setup-native-model.sh" "$D/"
  cat > "$D/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$DOCKER_LOG"
if [ "$1" = "create" ]; then echo stubcid; fi
if [ "$1" = "cp" ]; then
  [ -z "${DOCKER_CP_FAIL:-}" ] || exit 1
  dest="${@: -1}"; mkdir -p "$dest"; touch "$dest/model.onnx" "$dest/tokenizer.json"
fi
exit 0
STUB
  cat > "$D/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo called >> "$STUB_LOG"
out=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && out="$2"; shift; done
cp "$FIXTURE_TGZ" "$out"
STUB
  chmod +x "$D/bin/curl" "$D/bin/docker"
  : > "$D/curl.log"; : > "$D/docker.log"
}
run() { (cd "$D" && PATH="$D/bin:$PATH" STUB_LOG="$D/curl.log" DOCKER_LOG="$D/docker.log" FIXTURE_TGZ="$WORK/fixture.tgz" NATIVE_ARCH=arm64 "$@"); }
fail() { echo "FAIL: $*"; exit 1; }

# 1: already installed -> no curl, no docker
fresh installed
mkdir -p "$D/onnxruntime/lib" "$D/lm_model/onnx-e5"
touch "$D/onnxruntime/lib/libonnxruntime.dylib" "$D/lm_model/onnx-e5/model.onnx" "$D/lm_model/onnx-e5/tokenizer.json"
run ./setup-native-model.sh >/dev/null
[ ! -s "$D/curl.log" ] || fail "curl called when installed"
[ ! -s "$D/docker.log" ] || fail "docker called when installed"

# 2: not approved -> non-zero, no curl, name + source printed
fresh unapproved
echo "0000" > "$D/onnxruntime.sha256"
if OUT=$(run ./setup-native-model.sh 2>&1); then fail "ran without approval"; fi
[ ! -s "$D/curl.log" ] || fail "curl called without approval"
echo "$OUT" | grep -q "onnxruntime-osx-arm64-1.23.2.tgz" || fail "file name not shown"
echo "$OUT" | grep -q "github.com/microsoft/onnxruntime" || fail "source not shown"
echo "$OUT" | grep -qi "size is not known offline" || fail "size notice not shown"
echo "$OUT" | grep -q "github.com/microsoft/onnxruntime/releases/tag/v1.23.2" || fail "release page URL not shown"

# 3: approved, SHA mismatch -> non-zero, nothing extracted
fresh mismatch
printf '%064d\n' 0 > "$D/onnxruntime.sha256"
rc=0; run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null 2>&1 || rc=$?
[ "$rc" = 4 ] || fail "mismatching archive: expected exit 4, got $rc"
[ ! -e "$D/onnxruntime/lib/libonnxruntime.dylib" ] || fail "extracted despite mismatch"

# 4: approved, SHA matches -> library and model + tokenizer installed
fresh match
echo "$FIXTURE_SHA" > "$D/onnxruntime.sha256"
run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null
[ -f "$D/onnxruntime/lib/libonnxruntime.dylib" ] || fail "library not installed"
[ -f "$D/lm_model/onnx-e5/model.onnx" ] || fail "model.onnx not copied"
[ -f "$D/lm_model/onnx-e5/tokenizer.json" ] || fail "tokenizer.json not copied"
grep -q "dashboard-be-dev" "$D/docker.log" || fail "model not taken from the dev image"

# 4b: uppercase expected digest still matches (case-insensitive compare)
fresh upper
echo "$FIXTURE_SHA" | tr 'a-f' 'A-F' > "$D/onnxruntime.sha256"
run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null || fail "uppercase digest rejected"
[ -f "$D/onnxruntime/lib/libonnxruntime.dylib" ] || fail "library not installed with uppercase digest"

# 4c: expected digest not exactly 64 hex chars -> refused before any download
for bad in deadbeef "${FIXTURE_SHA}0" "${FIXTURE_SHA%?}g"; do
  fresh badhex
  echo "$bad" > "$D/onnxruntime.sha256"
  rc=0; run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null 2>&1 || rc=$?
  [ "$rc" = 3 ] || fail "malformed digest [$bad]: expected exit 3, got $rc"
  [ ! -s "$D/curl.log" ] || fail "curl called with malformed digest [$bad]"
done

# 4d: docker cp fails after docker create -> created container is removed
fresh cpfail
mkdir -p "$D/onnxruntime/lib"; touch "$D/onnxruntime/lib/libonnxruntime.dylib"
if run env DOCKER_CP_FAIL=1 ./setup-native-model.sh >/dev/null 2>&1; then fail "succeeded despite docker cp failure"; fi
grep -q '^rm .*stubcid' "$D/docker.log" || fail "created container not removed after docker cp failure"

# 5: missing digest file -> refuses before any download
fresh nodigest
if run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null 2>&1; then fail "ran without a pinned SHA256"; fi
[ ! -s "$D/curl.log" ] || fail "curl called without a pinned SHA256"

# 6: placeholder digest UNSET -> refuses before any download
fresh placeholder
echo "UNSET" > "$D/onnxruntime.sha256"
if run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null 2>&1; then fail "accepted placeholder digest"; fi
[ ! -s "$D/curl.log" ] || fail "curl called with placeholder digest"

# 7: committed digest file is either the UNSET placeholder or exactly 64 lowercase hex characters (the owner-approved official digest)
COMMITTED="$(tr -d '[:space:]' < "$SRC/onnxruntime.sha256")"
if [ "$COMMITTED" != "UNSET" ]; then
  printf '%s' "$COMMITTED" | grep -Eq '^[0-9a-f]{64}$' || fail "committed digest is neither UNSET nor 64 lowercase hex characters"
fi

# 8: library present but model missing -> only docker, no curl
fresh modelonly
mkdir -p "$D/onnxruntime/lib"; touch "$D/onnxruntime/lib/libonnxruntime.dylib"
run ./setup-native-model.sh >/dev/null
[ ! -s "$D/curl.log" ] || fail "curl called when library present"
[ -f "$D/lm_model/onnx-e5/tokenizer.json" ] || fail "model files not copied"

# 9: outputs are gitignored
cd "$SRC"
for f in onnxruntime/lib/libonnxruntime.dylib lm_model/onnx-e5/model.onnx lm_model/onnx-e5/tokenizer.json; do
  git check-ignore -q "$f" || fail "$f not gitignored"
done

echo "PASS (idempotent skip, approval gate, SHA256 gate, placeholder rejected, gitignore)"
