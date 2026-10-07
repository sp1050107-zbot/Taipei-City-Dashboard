# Phase 2 Hybrid Dev Environment Implementation Plan

> **For agentic workers:** This plan is the working draft of the *how*; execution follows `.scratch/phase2-hybrid-dev/spec.md` and `docs/decisions/0003-phase2-execution-engine-and-gates.md` (tickets under `.scratch/phase2-hybrid-dev/issues/`, run by `/implement-spec`). Where this plan and the spec differ, the spec wins. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task-to-ticket map:** Tasks 1-7 are tickets 02-08 in order (Task 1 = 02 ... Task 7 = 08); Task 8a = ticket 09; Task 8b = ticket 10. Ticket 01 is this plan revision.

**Goal:** Move FE and BE out of Docker so editing one line of either is visible in seconds on the host (with IDE/debugger attach), while DB/Redis/Qdrant stay containerized — without breaking the existing Phase 1 all-container stack.

**Architecture:** Keep `docker-compose-db.yaml` (postgres-data, postgres-manager, redis, qdrant) running and add host port mappings for the two services that don't have one yet (postgres-data, redis). Run FE via `npm run dev` and BE via `go run main.go` directly on the host, each pointed at `localhost:<port>` instead of the container DNS names baked into Phase 1. Two code-level blockers stand between "stop the fe/be containers" and "it actually works": the BE hardcodes a Linux-only ONNX Runtime library path, and the FE's non-Docker dev-server branch proxies to the real production site instead of a local backend. Both get fixed with minimal, backward-compatible changes (env-var override; new default branch) so Phase 1's containerized path is untouched.

**Tech Stack:** Go 1.24 (`go run`), Vue 3 + Vite (`npm run dev`), yalue/onnxruntime_go, Docker Compose (DB/Redis/Qdrant only), bash + plain Python for tests (no new test frameworks — matches current repo convention per `.planning/codebase/TESTING.md`).

**Spec:** `docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md` (§1 success criterion 2, §7 Phase 2). Supporting context: `.planning/HANDOFF-phase1.md`, `MEMORY.md`, `docs/agent-workflow/phase1-issue-log.md` (items B12, B18, B21, B27).

## Global Constraints

- All code/config/compose changes happen in a worktree with TDD, merged locally into `develop` only after green (AGENTS.md rule 1; spec §4). This plan assumes execution happens in a fresh worktree, not the integration checkout.
- Only `CLAUDE.md`/`AGENTS.md`/`MEMORY.md`/`docs/`/`.planning/` may be committed directly on the integration checkout (AGENTS.md rule 2) — every file this plan touches outside those paths must go through a worktree.
- No `git push`, no PR to upstream, unless the user explicitly says so (AGENTS.md rule 3).
- Secrets (`mapbox-key.txt`, `docker/.env`) are never committed and never printed; before any commit, diff against the literal secret value, never print it (AGENTS.md rule 4).
- No LLM/AI service keys are configured; the BE still unconditionally loads the local embedding model and onnxruntime at startup and calls `log.Fatalf` if either is missing (AGENTS.md rule 5) — Phase 2 must not remove that requirement, only make the library path host-portable.
- `docker compose` commands run only in the integration checkout (AGENTS.md rule 7); this plan's worktree tasks only edit compose YAML, they never run `docker compose up/build`.
- Success criterion this plan must satisfy (spec §1.2): change one FE line and one BE line, see the result on `localhost` within seconds, with IDE/debugger breakpoints working.

## Review Focus

- **FE dev proxy silently hits the real production site instead of the local BE.** `vite.config.js`'s non-Docker-Compose branch targets `https://citydashboard.taipei/api/v1`, not the local BE on `localhost:8088`; a developer running `npm run dev` natively after this phase would edit the BE, see no change, and not know why. Pinned by Task 5's test (native mode must target `http://localhost:8088`, frontend served on 8080).
- **A new FE `.env.local` holding the Mapbox token is not gitignored.** The repo's `.gitignore` only excludes `Taipei-City-Dashboard-FE/.env{,.development,.production,.test}` — `.env.local` (Vite's own local-override convention, which this plan introduces in Task 7) would slip through `git add` and leak the token on the first commit. Pinned by Task 6's test (must run *before* Task 7 creates the file).
- **The ONNX Runtime shared-library path is hardcoded to the Linux container path** (`app/models/qdrant.go:99`, `/usr/lib/libonnxruntime.so`). Native `go run` on macOS would call `log.Fatalf` on startup (AGENTS.md rule 5 behavior) with no way to point it at a macOS `.dylib`. Pinned by Task 1's test (env override must work).
- **postgres-data and redis have no host port mapping.** Only postgres-manager (`5432:5432`) and qdrant are reachable from the host; a natively-running BE would hang or connection-refuse against the other two. Pinned by Task 2's test (compose file must publish both ports) and Task 3's test (native launcher must point at them).
- **FE `node_modules` currently contains musl-linked native binaries** written by the Alpine-based init container (`docker-compose-init.yaml`'s `npm ci`, documented as B12 in `docs/agent-workflow/phase1-issue-log.md`). `npm run dev` on macOS against those binaries fails (wrong-platform native module). No unit test applies here (it's an OS/filesystem state, not code); pinned instead as an explicit, verifiable step in Task 8a (Step 5).

---

## File Structure

- `Taipei-City-Dashboard-BE/global/global.go` — modify: add `SharedLibraryPath` to `LMConfig`, sourced from `ORT_LIBRARY_PATH`.
- `Taipei-City-Dashboard-BE/global/global_test.go` — create: pins the new config field's default/override behavior by loading the real package-level configuration in a child process (not by rebuilding the value in the test).
- `Taipei-City-Dashboard-BE/app/models/qdrant.go` — modify: use `global.LM.SharedLibraryPath` instead of the hardcoded path.
- `docker/docker-compose-db.yaml` — modify: publish host ports for `postgres-data` (5433) and `redis` (6379).
- `docker/test-docker-compose-db.py` — create: asserts those port mappings exist (and that postgres-manager's didn't change).
- `Taipei-City-Dashboard-BE/dev-native.sh` — create: launches `go run main.go` with host-mode env overrides (including `GIN_PORT=8088`) layered on top of the real `docker/.env`.
- `Taipei-City-Dashboard-BE/test-dev-native.sh` — create: asserts the overrides using a fixture env file and a stub `go`, never touching the real secret file.
- `Taipei-City-Dashboard-BE/setup-native-model.sh` — create: idempotently fetches the macOS arm64 ONNX Runtime 1.23.2 library (only after owner approval, and only if its SHA256 matches) and copies the exported model out of the built dev image (`dashboard-be-dev:latest`) via `docker create` and `docker cp`.
- `Taipei-City-Dashboard-BE/onnxruntime.sha256` — create: the expected SHA256 of the official `onnxruntime-osx-arm64-1.23.2.tgz`, copied from the official release page by the implementer and confirmed by the owner at download approval.
- `Taipei-City-Dashboard-BE/test-setup-native-model.sh` — create: asserts the idempotent skip path, the no-download-without-approval path, and the SHA256 match/mismatch paths, all with a stub `curl`.
- `Taipei-City-Dashboard-FE/vite.server-config.js` — create: pure function resolving the dev-server `host`/`port`/`proxy` config from env, extracted so it's unit-testable without booting Vite.
- `Taipei-City-Dashboard-FE/vite.config.js` — modify: delegate to `resolveServerConfig`.
- `Taipei-City-Dashboard-FE/vite.server-config.test.mjs` — create: covers the three modes (compose / native-default / native-override).
- `.gitignore` (repo root) — modify: add the FE `.env.*.local` family.
- `Taipei-City-Dashboard-FE/test-env-local-ignored.sh` — create: asserts those paths are actually ignored.
- `Taipei-City-Dashboard-FE/make-dev-env.sh` — create: writes `.env.local` from `mapbox-key.txt`, never overwriting, never printing the token.
- `Taipei-City-Dashboard-FE/test-make-dev-env.sh` — create: asserts correct/no-overwrite/mode-600 behavior using a fake sentinel token (never a real one).

**Note on `*.sh` and `.gitignore`:** the repo's `.gitignore:29` ignores all `*.sh` except two DE scripts (documented as B4 in the issue log). Every new `.sh` file in this plan must be added with `git add -f <path>`, named explicitly — never `git add -A`/`git add .`.

---

### Task 1: Make the ONNX Runtime library path host-portable

**Files:**
- Modify: `Taipei-City-Dashboard-BE/global/global.go:44-46` (struct), `:133-135` (construction)
- Modify: `Taipei-City-Dashboard-BE/app/models/qdrant.go:99`
- Test: `Taipei-City-Dashboard-BE/global/global_test.go`

**Interfaces:**
- Produces: `global.LM.SharedLibraryPath string` — consumed by Task 3's `dev-native.sh` (sets `ORT_LIBRARY_PATH` before `go run`) and by `qdrant.go`'s `InitLmSession`.

- [ ] **Step 1: Write the failing test**

The configuration is read by package-level `var` initialisers, which run once when the package loads. So the test goes through that real reader by re-running the test binary as a child process with `ORT_LIBRARY_PATH` set (or unset) and printing what `global.LM.SharedLibraryPath` actually resolved to. The test never calls `getEnv` or builds an `LMConfig` itself.

```go
// Taipei-City-Dashboard-BE/global/global_test.go
package global

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

// TestHelperPrintLM is not a real test: when GO_WANT_LM_HELPER=1 it prints the
// value the real package-level config reader produced, then returns.
func TestHelperPrintLM(t *testing.T) {
	if os.Getenv("GO_WANT_LM_HELPER") != "1" {
		t.Skip("helper for the subprocess tests below")
	}
	os.Stdout.WriteString("SHARED_LIBRARY_PATH=" + LM.SharedLibraryPath + "\n")
}

// resolveSharedLibraryPath loads the package in a fresh process so the real
// initialisers read the environment we choose.
func resolveSharedLibraryPath(t *testing.T, ortPath *string) string {
	t.Helper()
	cmd := exec.Command(os.Args[0], "-test.run=^TestHelperPrintLM$", "-test.v")
	env := []string{}
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "ORT_LIBRARY_PATH=") {
			env = append(env, kv)
		}
	}
	env = append(env, "GO_WANT_LM_HELPER=1")
	if ortPath != nil {
		env = append(env, "ORT_LIBRARY_PATH="+*ortPath)
	}
	cmd.Env = env
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("child process failed: %v\n%s", err, out)
	}
	for _, line := range strings.Split(string(out), "\n") {
		if v, ok := strings.CutPrefix(line, "SHARED_LIBRARY_PATH="); ok {
			return v
		}
	}
	t.Fatalf("child did not print SHARED_LIBRARY_PATH:\n%s", out)
	return ""
}

func TestLMConfigSharedLibraryPathDefault(t *testing.T) {
	if got := resolveSharedLibraryPath(t, nil); got != "/usr/lib/libonnxruntime.so" {
		t.Fatalf("default SharedLibraryPath = %q, want /usr/lib/libonnxruntime.so", got)
	}
}

func TestLMConfigSharedLibraryPathOverride(t *testing.T) {
	override := "/opt/homebrew/lib/libonnxruntime.dylib"
	if got := resolveSharedLibraryPath(t, &override); got != override {
		t.Fatalf("overridden SharedLibraryPath = %q, want %q", got, override)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Taipei-City-Dashboard-BE && go test ./global/... -run TestLMConfigSharedLibraryPath -v`
Expected: build failure — `LM.SharedLibraryPath undefined (type LMConfig has no field or method SharedLibraryPath)`. This fails because the real configuration has no such field yet, not because of anything the test itself builds.

- [ ] **Step 3: Add the field and wire it in**

In `global/global.go`, change:
```go
type LMConfig struct {
	ModelPath    string
}
```
to:
```go
type LMConfig struct {
	ModelPath         string
	SharedLibraryPath string
}
```

And change:
```go
	LM = LMConfig{
		ModelPath: getEnv("LM_MODEL_PATH", "/opt/lm_model/onnx-e5/"),
	}
```
to:
```go
	LM = LMConfig{
		ModelPath:         getEnv("LM_MODEL_PATH", "/opt/lm_model/onnx-e5/"),
		SharedLibraryPath: getEnv("ORT_LIBRARY_PATH", "/usr/lib/libonnxruntime.so"),
	}
```

In `app/models/qdrant.go`, change line 99 from:
```go
	ort.SetSharedLibraryPath("/usr/lib/libonnxruntime.so") // 設定共享函式庫路徑
```
to:
```go
	ort.SetSharedLibraryPath(global.LM.SharedLibraryPath) // 容器內預設 /usr/lib/libonnxruntime.so；host 原生執行用 ORT_LIBRARY_PATH 覆寫
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Taipei-City-Dashboard-BE && go test ./global/... -run TestLMConfigSharedLibraryPath -v`
Expected: `PASS` for both `TestLMConfigSharedLibraryPathDefault` and `TestLMConfigSharedLibraryPathOverride`. Sanity check that the test can fail: temporarily change the default string in `global.go` and confirm the Default test goes red, then revert.

- [ ] **Step 5: Run the full BE test suite to confirm no regression**

Run: `cd Taipei-City-Dashboard-BE && go build ./... && go test ./...`
Expected: build succeeds; all existing tests (isochrone package) still pass.

- [ ] **Step 6: Commit**

```bash
git add Taipei-City-Dashboard-BE/global/global.go Taipei-City-Dashboard-BE/global/global_test.go Taipei-City-Dashboard-BE/app/models/qdrant.go
git commit -m "feat(be): make ONNX Runtime library path configurable via ORT_LIBRARY_PATH"
```

---

### Task 2: Publish host ports for postgres-data and redis

**Files:**
- Modify: `docker/docker-compose-db.yaml`
- Test: `docker/test-docker-compose-db.py`

**Interfaces:**
- Produces: host port `5433` → `postgres-data:5432`, host port `6379` → `redis:6379`. Consumed by Task 3's `dev-native.sh` (`DB_DASHBOARD_PORT=5433`, `REDIS_PORT=6379`).

- [ ] **Step 1: Write the failing test**

```python
#!/usr/bin/env python3
# docker/test-docker-compose-db.py
"""Verifies docker-compose-db.yaml exposes the host ports Phase 2's native BE needs."""
import pathlib

COMPOSE = pathlib.Path(__file__).parent / "docker-compose-db.yaml"


def _service_block(text, name, next_name):
    return text.split(f"{name}:")[1].split(f"{next_name}:")[0]


def test_postgres_data_port_mapped():
    text = COMPOSE.read_text()
    block = _service_block(text, "  postgres-data", "  postgres-manager")
    assert '"5433:5432"' in block, "postgres-data must publish host port 5433 -> 5432"


def test_redis_port_mapped():
    text = COMPOSE.read_text()
    block = _service_block(text, "  redis", "  postgres-data")
    assert '"6379:6379"' in block, "redis must publish host port 6379 -> 6379"


def test_postgres_manager_port_unchanged():
    text = COMPOSE.read_text()
    assert '"5432:5432"' in text, "postgres-manager host port mapping must stay 5432:5432"


if __name__ == "__main__":
    test_postgres_data_port_mapped()
    test_redis_port_mapped()
    test_postgres_manager_port_unchanged()
    print("PASS")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 docker/test-docker-compose-db.py`
Expected: `AssertionError: postgres-data must publish host port 5433 -> 5432` (neither mapping exists yet).

- [ ] **Step 3: Add the port mappings**

In `docker/docker-compose-db.yaml`, change the `redis` service from:
```yaml
  redis:
    restart: always
    container_name: redis
    image: redis:7.2.3-alpine
    volumes:
      - redis-data:/data
```
to:
```yaml
  redis:
    restart: always
    container_name: redis
    image: redis:7.2.3-alpine
    volumes:
      - redis-data:/data
    ports:
      - "6379:6379"
```

And change `postgres-data` from:
```yaml
  postgres-data:
    image: postgis/postgis:16-3.4-alpine
    container_name: postgres-data
    restart: always
    environment:
      POSTGRES_DB: ${DB_DASHBOARD_DBNAME}
      POSTGRES_USER: ${DB_DASHBOARD_USER}
      POSTGRES_PASSWORD: ${DB_DASHBOARD_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
```
to:
```yaml
  postgres-data:
    image: postgis/postgis:16-3.4-alpine
    container_name: postgres-data
    restart: always
    environment:
      POSTGRES_DB: ${DB_DASHBOARD_DBNAME}
      POSTGRES_USER: ${DB_DASHBOARD_USER}
      POSTGRES_PASSWORD: ${DB_DASHBOARD_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5433:5432"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 docker/test-docker-compose-db.py`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add docker/docker-compose-db.yaml docker/test-docker-compose-db.py
git commit -m "feat(docker): publish postgres-data and redis on host ports for native BE access"
```

**Note for the Verify step:** this is a compose *file* edit, not a `docker compose up` — per AGENTS.md rule 7, actually applying it (`docker compose -f docker-compose-db.yaml up -d`) happens later, in the integration checkout, not in this worktree.

---

### Task 3: Native launcher script for the BE

**Files:**
- Create: `Taipei-City-Dashboard-BE/dev-native.sh`
- Test: `Taipei-City-Dashboard-BE/test-dev-native.sh`

**Interfaces:**
- Consumes: `global.LM.SharedLibraryPath` env var name `ORT_LIBRARY_PATH` (Task 1); host ports `5433`/`6379` (Task 2).
- Produces: a `go run main.go` invocation with `DB_DASHBOARD_HOST=localhost`, `DB_DASHBOARD_PORT=5433`, `DB_MANAGER_HOST=localhost`, `REDIS_HOST=localhost`, `REDIS_PORT=6379`, `QDRANT_URL=http://localhost:6333`, `GIN_DOMAIN=localhost`, `GIN_PORT=8088` — consumed by Task 8a/8b.
- **No code dependency on Task 4.** The launcher uses the library and model locations that Task 4 produces (`onnxruntime/lib/libonnxruntime.dylib`, `lm_model/onnx-e5/`) only as default *values* for `ORT_LIBRARY_PATH` and `LM_MODEL_PATH`; it never calls or imports Task 4's script, so Tasks 3 and 4 stay parallel. The tests here use a stub `go` and need neither file. Task 8a/8b must confirm both are actually in place.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/test-dev-native.sh
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/fixture.env" <<'EOF'
JWT_SECRET=test-sentinel-secret
DB_DASHBOARD_USER=postgres
DB_DASHBOARD_PASSWORD=test-sentinel-pw
DB_DASHBOARD_DBNAME=dashboard
DB_MANAGER_USER=postgres
DB_MANAGER_PASSWORD=test-sentinel-pw
DB_MANAGER_DBNAME=dashboardmanager
EOF

mkdir -p "$WORK/bin"
cat > "$WORK/bin/go" <<'EOF'
#!/usr/bin/env bash
env
EOF
chmod +x "$WORK/bin/go"

OUT=$(PATH="$WORK/bin:$PATH" DEV_NATIVE_ENV_FILE="$WORK/fixture.env" ./dev-native.sh)

assert() {
  echo "$OUT" | grep -qx "$1" || { printf 'FAIL: expected line [%s]\n--- actual ---\n%s\n' "$1" "$OUT"; exit 1; }
}
assert "DB_DASHBOARD_HOST=localhost"
assert "DB_DASHBOARD_PORT=5433"
assert "DB_MANAGER_HOST=localhost"
assert "DB_MANAGER_PORT=5432"
assert "REDIS_HOST=localhost"
assert "REDIS_PORT=6379"
assert "QDRANT_URL=http://localhost:6333"
assert "GIN_DOMAIN=localhost"
assert "GIN_PORT=8088"
assert "JWT_SECRET=test-sentinel-secret"
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x Taipei-City-Dashboard-BE/test-dev-native.sh && Taipei-City-Dashboard-BE/test-dev-native.sh`
Expected: `./dev-native.sh: No such file or directory`.

- [ ] **Step 3: Write the script**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/dev-native.sh
# Phase 2 hybrid dev: run the BE natively on the host against the
# Dockerized DB/Redis/Qdrant. Reads the real secrets from docker/.env, then
# overrides only the values that differ for host networking.
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE="${DEV_NATIVE_ENV_FILE:-../docker/.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE - run docs/agent-workflow/make-env.sh first" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

export DB_DASHBOARD_HOST=localhost
export DB_DASHBOARD_PORT=5433
export DB_MANAGER_HOST=localhost
export DB_MANAGER_PORT=5432
export REDIS_HOST=localhost
export REDIS_PORT=6379
export QDRANT_URL=http://localhost:6333
export GIN_DOMAIN=localhost
export GIN_PORT=8088
# Defaults point at where Task 4's setup script puts the files; this script does not run or depend on it.
export ORT_LIBRARY_PATH="${ORT_LIBRARY_PATH:-$(pwd)/onnxruntime/lib/libonnxruntime.dylib}"
export LM_MODEL_PATH="${LM_MODEL_PATH:-$(pwd)/lm_model/onnx-e5/}"

exec go run main.go "$@"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x Taipei-City-Dashboard-BE/dev-native.sh && Taipei-City-Dashboard-BE/test-dev-native.sh`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add -f Taipei-City-Dashboard-BE/dev-native.sh Taipei-City-Dashboard-BE/test-dev-native.sh
git commit -m "feat(be): add native dev launcher with host-mode env overrides"
```

---

### Task 4: macOS ONNX Runtime + model setup script

**Files:**
- Create: `Taipei-City-Dashboard-BE/setup-native-model.sh`
- Create: `Taipei-City-Dashboard-BE/onnxruntime.sha256`
- Test: `Taipei-City-Dashboard-BE/test-setup-native-model.sh`

**Interfaces:**
- Produces: `Taipei-City-Dashboard-BE/onnxruntime/lib/libonnxruntime.dylib` and `Taipei-City-Dashboard-BE/lm_model/onnx-e5/model.onnx` — both already covered by `Taipei-City-Dashboard-BE/.gitignore`'s existing `lm_model`/`onnxruntime` entries. Task 3's `dev-native.sh` uses these locations only as default values (no code dependency); Task 8a/8b confirm both files exist.

**Rules this task must satisfy (spec user stories 13-15):**
- The script downloads only the official `onnxruntime-osx-arm64-1.23.2.tgz` release asset, and **never downloads anything until the owner has approved**. Before asking, the implementer tells the owner in chat the file name, the source URL and the size (read from the official release page, not by downloading), and waits for a clear yes. The script enforces this: without `ORT_DOWNLOAD_APPROVED=yes` it prints the file name and source URL, makes no network call, and exits non-zero. The implementer sets that variable only after the owner's yes.
- **The archive's SHA256 must match the expected value before anything is extracted or used.** On mismatch the script deletes the download, extracts nothing, and exits non-zero. The expected value lives in `onnxruntime.sha256` (one line, hex digest). The implementer copies it from the official release page and the owner confirms it when approving; if the digest cannot be obtained from the official source, the implementer stops and reports UNVERIFIED instead of guessing or computing it from the unverified download. An empty or missing `onnxruntime.sha256` makes the script refuse to download.
- Host scope is macOS arm64 only (spec Out of Scope); other architectures exit with an error.

- [ ] **Step 1: Write the failing test (idempotency, approval, SHA256)**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/test-setup-native-model.sh
set -euo pipefail
cd "$(dirname "$0")"
SRC="$(pwd)"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# One fixed fake archive, built once, so its SHA256 is stable across stub calls.
mkdir -p "$WORK/pkg/onnxruntime-osx-arm64-1.23.2/lib"
echo fake > "$WORK/pkg/onnxruntime-osx-arm64-1.23.2/lib/libonnxruntime.dylib"
tar -czf "$WORK/fixture.tgz" -C "$WORK/pkg" onnxruntime-osx-arm64-1.23.2
FIXTURE_SHA="$(shasum -a 256 "$WORK/fixture.tgz" | cut -d' ' -f1)"

fresh() { # fresh <case-name>: an empty sandbox with the script and stubs
  D="$WORK/$1"; mkdir -p "$D/bin"
  cp "$SRC/setup-native-model.sh" "$D/"
  cat > "$D/bin/docker" <<'EOF'
#!/usr/bin/env bash
mkdir -p lm_model/onnx-e5 && touch lm_model/onnx-e5/model.onnx
EOF
  # stub curl: copies the fixed fake archive to -o <file>, and logs the call
  cat > "$D/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo called >> "$STUB_LOG"
out=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && out="$2"; shift; done
cp "$FIXTURE_TGZ" "$out"
EOF
  chmod +x "$D/bin/curl" "$D/bin/docker"
  : > "$D/curl.log"
}
run() { (cd "$D" && PATH="$D/bin:$PATH" STUB_LOG="$D/curl.log" FIXTURE_TGZ="$WORK/fixture.tgz" NATIVE_ARCH=arm64 CURL_BIN=curl DOCKER_BIN=docker "$@"); }

# Case 1: already installed -> no curl, no docker
fresh installed
mkdir -p "$D/onnxruntime/lib" "$D/lm_model/onnx-e5"; touch "$D/onnxruntime/lib/libonnxruntime.dylib" "$D/lm_model/onnx-e5/model.onnx"
printf '#!/usr/bin/env bash\necho "docker must not run" >&2; exit 1\n' > "$D/bin/docker"
printf '#!/usr/bin/env bash\necho "curl must not run" >&2; exit 1\n' > "$D/bin/curl"
run ./setup-native-model.sh

# Case 2: not approved -> exits non-zero, curl never called, file name + source printed
fresh unapproved
echo "0000" > "$D/onnxruntime.sha256"
if OUT=$(run ./setup-native-model.sh 2>&1); then echo "FAIL: ran without approval"; exit 1; fi
[ ! -s "$D/curl.log" ] || { echo "FAIL: curl called without approval"; exit 1; }
echo "$OUT" | grep -q "onnxruntime-osx-arm64-1.23.2.tgz" || { echo "FAIL: file name not shown"; exit 1; }
echo "$OUT" | grep -q "github.com/microsoft/onnxruntime" || { echo "FAIL: source not shown"; exit 1; }

# Case 3: approved but SHA256 mismatch -> non-zero, nothing extracted, download removed
fresh mismatch
echo "deadbeef" > "$D/onnxruntime.sha256"
if run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null 2>&1; then echo "FAIL: accepted a mismatching archive"; exit 1; fi
[ ! -e "$D/onnxruntime/lib/libonnxruntime.dylib" ] || { echo "FAIL: extracted despite mismatch"; exit 1; }

# Case 4: approved, SHA256 matches -> installed
fresh match
echo "$FIXTURE_SHA" > "$D/onnxruntime.sha256"
run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null
[ -f "$D/onnxruntime/lib/libonnxruntime.dylib" ] || { echo "FAIL: not installed after matching SHA256"; exit 1; }

# Case 5: missing/empty digest file -> refuses before any download
fresh nodigest
if run env ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh >/dev/null 2>&1; then echo "FAIL: ran without a pinned SHA256"; exit 1; fi
[ ! -s "$D/curl.log" ] || { echo "FAIL: curl called without a pinned SHA256"; exit 1; }

echo "PASS (idempotent skip, approval gate, SHA256 gate verified)"
```

- [ ] **Step 2: Write a naive (unconditional) first version and confirm RED**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/setup-native-model.sh (naive first draft)
set -euo pipefail
cd "$(dirname "$0")"

ORT_VERSION="1.23.2"
ORT_ASSET="onnxruntime-osx-arm64-${ORT_VERSION}.tgz"

mkdir -p onnxruntime
URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_ASSET}"
"${CURL_BIN:-curl}" -fL "$URL" -o /tmp/ort.tgz
tar -xzf /tmp/ort.tgz -C onnxruntime --strip-components=1
rm -f /tmp/ort.tgz

mkdir -p lm_model/onnx-e5
"${DOCKER_BIN:-docker}" cp dashboard-be:/opt/lm_model/onnx-e5/. lm_model/onnx-e5/
```

Run: `chmod +x Taipei-City-Dashboard-BE/setup-native-model.sh Taipei-City-Dashboard-BE/test-setup-native-model.sh && Taipei-City-Dashboard-BE/test-setup-native-model.sh`
Expected: `FAIL` — Case 1's stub `curl` exits 1 with `curl must not run`, because the naive script downloads unconditionally (and Cases 2, 3 and 5 would also fail: no approval gate, no SHA256 check).

- [ ] **Step 3: Add the idempotency, approval and SHA256 guards**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/setup-native-model.sh
# Phase 2 hybrid dev: fetch the macOS arm64 ONNX Runtime library (owner-approved,
# SHA256-verified) and the exported e5 model out of the already-built
# dashboard-be container, so native `go run` has what the container build
# produced without re-running the Python export pipeline on the host.
set -euo pipefail
cd "$(dirname "$0")"

ORT_VERSION="1.23.2"
ORT_LIB="onnxruntime/lib/libonnxruntime.dylib"
MODEL_FILE="lm_model/onnx-e5/model.onnx"
ORT_ASSET="onnxruntime-osx-arm64-${ORT_VERSION}.tgz"
ORT_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_ASSET}"
SHA_FILE="${ORT_SHA256_FILE:-onnxruntime.sha256}"

ARCH="${NATIVE_ARCH:-$(uname -m)}"
[ "$ARCH" = "arm64" ] || { echo "unsupported arch: $ARCH (macOS arm64 only)" >&2; exit 1; }

if [ -f "$ORT_LIB" ]; then
  echo "onnxruntime already installed at $ORT_LIB"
else
  echo "About to download: $ORT_ASSET"
  echo "Source: $ORT_URL"
  if [ "${ORT_DOWNLOAD_APPROVED:-}" != "yes" ]; then
    echo "Not approved: ask the owner first, then rerun with ORT_DOWNLOAD_APPROVED=yes" >&2
    exit 2
  fi
  EXPECTED="$(tr -d '[:space:]' < "$SHA_FILE" 2>/dev/null || true)"
  [ -n "$EXPECTED" ] || { echo "missing or empty $SHA_FILE: copy the official SHA256 first" >&2; exit 3; }

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  "${CURL_BIN:-curl}" -fL "$ORT_URL" -o "$TMP/ort.tgz"
  ACTUAL="$(shasum -a 256 "$TMP/ort.tgz" | cut -d' ' -f1)"
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "SHA256 mismatch for $ORT_ASSET (expected $EXPECTED, got $ACTUAL); nothing extracted" >&2
    exit 4
  fi
  mkdir -p onnxruntime
  tar -xzf "$TMP/ort.tgz" -C onnxruntime --strip-components=1
  echo "installed onnxruntime -> $ORT_LIB (SHA256 verified)"
fi

if [ -f "$MODEL_FILE" ]; then
  echo "model already exported at $MODEL_FILE"
else
  mkdir -p lm_model/onnx-e5
  "${DOCKER_BIN:-docker}" cp dashboard-be:/opt/lm_model/onnx-e5/. lm_model/onnx-e5/
  echo "copied model -> $MODEL_FILE"
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Taipei-City-Dashboard-BE/test-setup-native-model.sh`
Expected: `PASS (idempotent skip, approval gate, SHA256 gate verified)`. The test never touches the network or Docker; the real download happens only in Task 8a, after the owner approves.

- [ ] **Step 5: Commit**

```bash
git add -f Taipei-City-Dashboard-BE/setup-native-model.sh Taipei-City-Dashboard-BE/test-setup-native-model.sh Taipei-City-Dashboard-BE/onnxruntime.sha256
git commit -m "feat(be): add approval- and SHA256-gated macOS onnxruntime+model setup"
```

(`onnxruntime.sha256` is committed once the implementer has the official digest. If it cannot be obtained, commit without it, leave the item UNVERIFIED in the ticket, and let Task 8a ask the owner.)

---

### Task 5: Fix the FE dev-server proxy default and extract it for testing

**Files:**
- Create: `Taipei-City-Dashboard-FE/vite.server-config.js`
- Modify: `Taipei-City-Dashboard-FE/vite.config.js`
- Test: `Taipei-City-Dashboard-FE/vite.server-config.test.mjs`

**Interfaces:**
- Produces: `resolveServerConfig(env: Record<string,string>) -> { host, port, proxy }`, exported from `vite.server-config.js`. Consumed by `vite.config.js`'s `server:` field.

- [ ] **Step 1: Write the failing test**

```js
// Taipei-City-Dashboard-FE/vite.server-config.test.mjs
import assert from "node:assert/strict";
import { resolveServerConfig } from "./vite.server-config.js";

// Docker Compose mode (Phase 1): the FE container listens on 80 (host-published as 8080) and proxies to the BE container by name on its in-container port (the BE is host-published as 8088).
{
	const cfg = resolveServerConfig({ DOCKER_COMPOSE: "true" });
	assert.equal(cfg.port, 80);
	assert.equal(cfg.proxy["/api/dev"].target, "http://dashboard-be:8080");
}

// Native host dev (Phase 2 default): serve the FE on host port 8080 (no root needed) and proxy to the native BE on localhost:8088.
{
	const cfg = resolveServerConfig({});
	assert.equal(cfg.port, 8080);
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:8088");
}

// Native host dev with an overridden local BE URL.
{
	const cfg = resolveServerConfig({ VITE_LOCAL_BE_URL: "http://localhost:9999" });
	assert.equal(cfg.proxy["/api/dev"].target, "http://localhost:9999");
}

console.log("PASS");
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node Taipei-City-Dashboard-FE/vite.server-config.test.mjs`
Expected: `Cannot find module './vite.server-config.js'`.

- [ ] **Step 3: Write the config resolver**

```js
// Taipei-City-Dashboard-FE/vite.server-config.js
/**
 * Pure server-config resolver for vite.config.js, kept separate so the
 * environment-driven proxy/port decision is unit-testable without booting Vite.
 */
export function resolveServerConfig(env) {
	const isDockerCompose = env.DOCKER_COMPOSE === "true";

	if (isDockerCompose) {
		return {
			host: "0.0.0.0",
			port: 80,
			proxy: {
				"/api/dev": {
					target: "http://dashboard-be:8080", // container-internal BE port (Phase 1 only; the host-published BE port is 8088)
					changeOrigin: true,
					rewrite: (path) => path.replace("/dev", "/v1"),
				},
			},
		};
	}

	return {
		host: "0.0.0.0",
		port: 8080,
		proxy: {
			"/api/dev": {
				target: env.VITE_LOCAL_BE_URL || "http://localhost:8088",
				changeOrigin: true,
				rewrite: (path) => path.replace("/dev", "/v1"),
			},
		},
	};
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node Taipei-City-Dashboard-FE/vite.server-config.test.mjs`
Expected: `PASS`.

- [ ] **Step 5: Wire it into vite.config.js**

Replace the inline `isDockerCompose`/`serverConfig` block in `vite.config.js` with:
```js
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import viteCompression from "vite-plugin-compression";
import { resolveServerConfig } from "./vite.server-config.js";

export default defineConfig({
	plugins: [vue(), viteCompression()],
	build: {
		rollupOptions: {
			output: {
				manualChunks(id) {
					if (id.includes("node_modules")) {
						return id
							.toString()
							.split("node_modules/")[1]
							.split("/")[0]
							.toString();
					}
				},
			},
		},
		chunkSizeWarningLimit: 1600,
	},
	base: "/",
	server: resolveServerConfig(process.env),
});
```

- [ ] **Step 6: Confirm the FE still builds**

Run: `cd Taipei-City-Dashboard-FE && npm run build`
Expected: build succeeds (lint + vite build), no reference errors to the removed inline block.

- [ ] **Step 7: Commit**

```bash
git add Taipei-City-Dashboard-FE/vite.server-config.js Taipei-City-Dashboard-FE/vite.config.js Taipei-City-Dashboard-FE/vite.server-config.test.mjs
git commit -m "fix(fe): default native dev-server proxy to local BE instead of production"
```

---

### Task 6: Close the `.env.local` gitignore gap (must land before Task 7)

**Files:**
- Modify: `.gitignore` (repo root)
- Test: `Taipei-City-Dashboard-FE/test-env-local-ignored.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-FE/test-env-local-ignored.sh
set -euo pipefail
cd "$(dirname "$0")/.."  # repo root, so git check-ignore sees the real .gitignore

for f in \
  Taipei-City-Dashboard-FE/.env.local \
  Taipei-City-Dashboard-FE/.env.development.local \
  Taipei-City-Dashboard-FE/.env.production.local \
  Taipei-City-Dashboard-FE/.env.test.local; do
  git check-ignore -q "$f" || { echo "FAIL: $f is NOT gitignored"; exit 1; }
done
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x Taipei-City-Dashboard-FE/test-env-local-ignored.sh && Taipei-City-Dashboard-FE/test-env-local-ignored.sh`
Expected: `FAIL: Taipei-City-Dashboard-FE/.env.local is NOT gitignored`.

- [ ] **Step 3: Extend .gitignore**

In the root `.gitignore`, change:
```
# .env files except for template
docker/.env
Taipei-City-Dashboard-FE/.env
Taipei-City-Dashboard-FE/.env.development
Taipei-City-Dashboard-FE/.env.production
Taipei-City-Dashboard-FE/.env.test
```
to:
```
# .env files except for template
docker/.env
Taipei-City-Dashboard-FE/.env
Taipei-City-Dashboard-FE/.env.development
Taipei-City-Dashboard-FE/.env.production
Taipei-City-Dashboard-FE/.env.test
Taipei-City-Dashboard-FE/.env.local
Taipei-City-Dashboard-FE/.env.development.local
Taipei-City-Dashboard-FE/.env.production.local
Taipei-City-Dashboard-FE/.env.test.local
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Taipei-City-Dashboard-FE/test-env-local-ignored.sh`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add -f .gitignore Taipei-City-Dashboard-FE/test-env-local-ignored.sh
git commit -m "fix(fe): gitignore .env.local family before it can hold the Mapbox token"
```

---

### Task 7: Generate the FE native `.env.local` from `mapbox-key.txt`

**Depends on:** Task 6 (the file this creates must already be gitignored).

**Files:**
- Create: `Taipei-City-Dashboard-FE/make-dev-env.sh`
- Test: `Taipei-City-Dashboard-FE/test-make-dev-env.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-FE/test-make-dev-env.sh
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "pk.TESTSENTINELTOKEN12345" > "$WORK/mapbox-key.txt"

MAPBOX_KEY_FILE="$WORK/mapbox-key.txt" ENV_LOCAL_OUT="$WORK/.env.local" ./make-dev-env.sh

grep -qx "VITE_MAPBOXTOKEN=pk.TESTSENTINELTOKEN12345" "$WORK/.env.local" || { echo "FAIL: token not written correctly"; exit 1; }

PERM="$(stat -f '%Lp' "$WORK/.env.local" 2>/dev/null || stat -c '%a' "$WORK/.env.local")"
[ "$PERM" = "600" ] || { echo "FAIL: expected mode 600, got $PERM"; exit 1; }

if MAPBOX_KEY_FILE="$WORK/mapbox-key.txt" ENV_LOCAL_OUT="$WORK/.env.local" ./make-dev-env.sh 2>/dev/null; then
  echo "FAIL: should refuse to overwrite existing file"; exit 1
fi

echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x Taipei-City-Dashboard-FE/test-make-dev-env.sh && Taipei-City-Dashboard-FE/test-make-dev-env.sh`
Expected: `./make-dev-env.sh: No such file or directory`.

- [ ] **Step 3: Write the script**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-FE/make-dev-env.sh
# Phase 2 hybrid dev: generate .env.local for native `npm run dev` from the
# user's own mapbox-key.txt. Never overwrites, never prints the token.
set -euo pipefail
cd "$(dirname "$0")"

KEY_FILE="${MAPBOX_KEY_FILE:-../mapbox-key.txt}"
OUT_FILE="${ENV_LOCAL_OUT:-.env.local}"

if [ -e "$OUT_FILE" ]; then
  echo "refusing to overwrite existing $OUT_FILE" >&2
  exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
  echo "missing $KEY_FILE - see docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md §9.1" >&2
  exit 1
fi

TOKEN="$(tr -d '[:space:]' < "$KEY_FILE")"
if [ -z "$TOKEN" ]; then
  echo "$KEY_FILE is empty" >&2
  exit 1
fi

cat > "$OUT_FILE" <<EOF
VITE_API_URL=/api/dev
VITE_APP_TITLE=臺北城市儀表板
VITE_APP_VERSION=2.0.0
VITE_MAPBOXTOKEN=${TOKEN}
VITE_MAPBOXTILE=
EOF
chmod 600 "$OUT_FILE"
echo "wrote $OUT_FILE"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Taipei-City-Dashboard-FE/test-make-dev-env.sh`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add -f Taipei-City-Dashboard-FE/make-dev-env.sh Taipei-City-Dashboard-FE/test-make-dev-env.sh
git commit -m "feat(fe): generate native .env.local from mapbox-key.txt without ever printing it"
```

---

### Task 8a: Native dev runbook and environment ready (ticket 09)

**Depends on:** Tasks 1-7 merged to the integration branch, plus the Phase 1 stack's DB containers already initialized (per `.planning/HANDOFF-phase1.md` — init is one-shot, do not rerun it, AGENTS.md rule 9).

**Files:**
- Create: `docs/agent-workflow/phase2-native-dev-runbook.md` (the runbook)
- Create: `docs/agent-workflow/evidence/phase2/` entries for every claim the runbook makes (command plus output; no secrets)

**Stack rule (decision 0002):** Phase 1 and Phase 2 never run at the same time. During Phase 2 the frontend serves on host port **8080** and the backend on **8088** (`GIN_PORT=8088`), the same ports Phase 1 used, so the two Phase 1 application containers must be stopped first. The runbook states this in one sentence near the top and uses 8080 (frontend) and 8088 (backend) everywhere.

This task has no unit test of its own; Tasks 1-7's tests cover the code. Run each step for real and store the actual output (per superpowers:verification-before-completion). Anything not proven is reported as UNVERIFIED.

- [ ] **Step 1: Ask the owner, wait for a clear yes, then apply Task 2's compose change in the integration checkout**

Recreating `postgres-data` and `redis` is the only step that touches the databases, so the implementer asks first. Volumes are kept and initialization is not rerun. In `~/Taipei-City-Dashboard/docker` (not a worktree — AGENTS.md rule 7):
```bash
docker compose -f docker-compose-db.yaml up -d
docker compose -f docker-compose-db.yaml ps
```
Expected: `postgres-data`, `postgres-manager`, `redis`, `qdrant` all `running`; `docker port postgres-data` shows `5432/tcp -> 0.0.0.0:5433`; `docker port redis` shows `6379/tcp -> 0.0.0.0:6379`.

- [ ] **Step 2: Stop the containerized FE/BE (keep DB/Redis/Qdrant up)**

```bash
docker compose -f docker-compose.yaml stop dashboard-fe dashboard-be
```
Expected: both containers `Exited`, freeing host ports 8080 and 8088; the four infra containers from Step 1 stay `running`.

- [ ] **Step 3: Set up the BE's native runtime (download only with owner approval)**

```bash
cd Taipei-City-Dashboard-BE
./setup-native-model.sh
```
First run without approval prints the file name and source and exits non-zero. Tell the owner the file name, source and size, wait for a yes, then rerun with `ORT_DOWNLOAD_APPROVED=yes ./setup-native-model.sh`. Expected: `installed onnxruntime -> onnxruntime/lib/libonnxruntime.dylib (SHA256 verified)` and `copied model -> lm_model/onnx-e5/model.onnx` (first run); `already installed`/`already exported` on reruns. A SHA256 mismatch is a stop-and-report, not a retry.

- [ ] **Step 4: Ask the owner before installing Node 21, then pin FE and BE toolchains**

Do not install Node 21 until the owner says yes. Then pin the FE to Node 21 (e.g. `nvm use 21` or the project's version file) and run the BE with the host Go toolchain only (`GOTOOLCHAIN=local`, no toolchain download). Record `node --version` and `go version` in the evidence. Whether Node 21 installs the existing lock file cleanly on macOS arm64 and whether host Go builds this project are UNVERIFIED until this step shows it.

- [ ] **Step 5: Reinstall FE node_modules natively (clears the musl binaries from the Alpine init container — B12)**

```bash
cd ../Taipei-City-Dashboard-FE
rm -rf node_modules package-lock.json
npm install
```
Expected: install completes with no platform-mismatch errors, and `npm run dev` later starts without an `invalid ELF header`-style error.

- [ ] **Step 6: Confirm both Task 3 and Task 4 outputs are in place**

Tasks 3 and 4 are parallel with no code dependency (Task 3 only defaults to Task 4's output locations), so this is where the join is checked:
```bash
test -f Taipei-City-Dashboard-BE/onnxruntime/lib/libonnxruntime.dylib && echo ort-ok
test -f Taipei-City-Dashboard-BE/lm_model/onnx-e5/model.onnx && echo model-ok
test -x Taipei-City-Dashboard-BE/dev-native.sh && echo launcher-ok
```
Expected: `ort-ok`, `model-ok`, `launcher-ok`. Anything missing: stop and report.

- [ ] **Step 7: Write the runbook and store evidence**

`docs/agent-workflow/phase2-native-dev-runbook.md` contains: how to start Phase 2 (Steps 1-6 condensed, with the approval points), the one-stack-at-a-time statement, how to record the HMR and BE-restart timings, and a **Return to Phase 1** section: stop the native FE and BE processes, then in the integration checkout `docker compose -f docker-compose.yaml up -d dashboard-fe dashboard-be`, then probe `curl -i http://localhost:8088/api/v1/dashboard/` (trailing slash, see `docs/decisions/0001-phase1-deploy-approach.md` ruling 6) and expect `200`; the extra published ports 5433 and 6379 need no undoing. Store each claim's command and output under `docs/agent-workflow/evidence/phase2/`.

```bash
git add docs/agent-workflow/phase2-native-dev-runbook.md docs/agent-workflow/evidence/phase2/
git commit -m "docs: add Phase 2 native dev runbook and environment-ready evidence"
```
Commit in the worktree only; nothing is pushed.

---

### Task 8b: Phase 2 acceptance by a fresh verifier session (ticket 10)

**Depends on:** Task 8a. **The verifier is a new session that implemented none of tickets 01-09**, so the implementer does not grade their own work. No code is changed here; a finding that needs a fix becomes a new ticket.

**Files:**
- Create: `docs/agent-workflow/evidence/phase2/acceptance.md` (checklist results with command output; no secrets)

Ports are frontend **8080** and backend **8088** throughout (decision 0002). Run every step for real and paste actual output; anything unproven stays UNVERIFIED.

- [ ] **Step 1: Run the BE natively and probe it**

```bash
cd Taipei-City-Dashboard-BE
./dev-native.sh
```
Expected: the process logs the embedding model loading successfully (no `log.Fatalf`) and stays up, then Gin listens on `localhost:8088` (`GIN_PORT=8088` from the launcher). Probe: `curl -i http://localhost:8088/api/v1/dashboard/` (trailing slash — decision 0001 ruling 6) returns `200`; databases and Redis connect (no connection errors in the log).

- [ ] **Step 2: Run the FE natively**

```bash
cd ../Taipei-City-Dashboard-FE
./make-dev-env.sh
npm run dev
```
Expected: Vite dev server on `http://localhost:8080` (Task 5's `resolveServerConfig` default); `/api/dev/...` requests are proxied to `http://localhost:8088`, not to the production site (confirm in the network tab or via `curl -i http://localhost:8080/api/dev/dashboard/` returning `200`); the dashboard page, the map page (tiles render with the Mapbox token from `.env.local`) and the admin page all load. Record the exact ports used.

- [ ] **Step 3: Prove the hot-loop (spec §1 success criterion 2)**

Change one line in `Taipei-City-Dashboard-FE/src/` (e.g. a label string) and one line in `Taipei-City-Dashboard-BE/app/controllers/` (e.g. a log message) while both dev processes are running. Expected: the FE change appears via Vite HMR in about 1 second with no manual reload; the BE change needs killing and rerunning `./dev-native.sh` (plain `go run`, no hot-reload) and is live within a few seconds. **Record both as measured numbers in seconds.** Revert the edits afterwards.

- [ ] **Step 4: Confirm debugger attach**

BE: open `Taipei-City-Dashboard-BE` in VS Code or GoLand, set a breakpoint in a controller, launch via "Run and Debug" (uses `dlv`) instead of `./dev-native.sh`, hit the endpoint, confirm the breakpoint pauses. FE: in the browser DevTools Sources, set a breakpoint in a `.vue` file (Vite serves real source maps), confirm it pauses. Record the tool used for each and that both breakpoints were hit.

- [ ] **Step 5: Execute the Return-to-Phase-1 section**

Follow the runbook's section exactly: stop the native FE and BE, restart `dashboard-fe` and `dashboard-be` in the integration checkout, confirm `curl -i http://localhost:8088/api/v1/dashboard/` returns `200`. Record the output.

- [ ] **Step 6: Secret scan and gitignore check**

Compare all staged changes against the full text of the Mapbox token and the `docker/.env` secrets (compare only, never print them), and run `git check-ignore -v Taipei-City-Dashboard-FE/.env.local`. Expected: scan clean; `.env.local` is reported as ignored.

- [ ] **Step 7: Admin login is the owner's, not an agent's**

Ask the owner to log in to the admin page themselves and report the result. No agent logs in or reads the admin password. Until the owner reports, this item stays **UNVERIFIED**.

- [ ] **Step 8: Close out the UNVERIFIED list**

For each spec "Further Notes" UNVERIFIED item (ONNX Runtime 1.23.2 compatibility with the Go binding, host Go build, Node 21 install, `.env.local` non-leak, and the status code of `POST /component` when the Qdrant collection is missing), either attach the command output that proves it or leave it explicitly marked UNVERIFIED with the reason.

- [ ] **Step 9: Write the evidence file and commit**

Write `docs/agent-workflow/evidence/phase2/acceptance.md` with the real output from Steps 1-8 (ports, status codes, HMR and restart timings, debugger tool names, no secrets).

```bash
git add docs/agent-workflow/evidence/phase2/acceptance.md
git commit -m "docs: record Phase 2 acceptance evidence"
```

---

## Self-Review

**Spec coverage:** §1 success criterion 2 (edit FE/BE, see it in seconds, debugger works) → Task 8b (acceptance by a fresh verifier). §7 "Docker 只留 postgres-data、postgres-manager、redis（必要時 qdrant）；FE `npm run dev`、BE `go run`" → Tasks 1-5 (code) + Tasks 8a/8b (runbook, acceptance). §7 "改 env 的 host 為 localhost，確認各 DB 埠有對外映射" → Tasks 2-3. §7 "風險：onnxruntime 在 Apple Silicon 原生執行" → Tasks 1 and 4 (this plan treats it as solvable via a configurable library path + a macOS binary fetch, not as an open risk anymore — Task 8b Step 1 is where that gets proven or disproven for real). §7 "這些變更屬 compose/設定變更，走 worktree 流程" → Global Constraints. §7 optional "TCD-B1 MapLibre + OpenFreeMap" and issue-log B27 (GA tracking removal) are **explicitly out of scope** for this plan — spec §7 itself calls MapLibre "選配，由使用者決定是否做"; neither blocks the hybrid-dev goal, so they stay separate future `B 客製開發` tasks.

**Placeholder scan:** none found — every step has runnable code/commands and concrete expected output.

**Type consistency:** `global.LM.SharedLibraryPath` (Task 1) is the only new Go identifier and it's used identically in `global.go` and `qdrant.go`. `resolveServerConfig(env)` (Task 5) has one signature used identically in the test and in `vite.config.js`. `ORT_LIBRARY_PATH`, `LM_MODEL_PATH`, `DEV_NATIVE_ENV_FILE` (Tasks 1/3/4) are used with the same names and defaults across the scripts that produce and consume them.

**Review Focus:** all five items listed above have an owning task and a test (four unit/integration tests, one explicit runbook step for the one OS-state issue that isn't code). No additional gaps found.

---

## Execution Handoff

This plan is no longer executed by choosing between Subagent-driven and Native. Execution follows `docs/decisions/0003-phase2-execution-engine-and-gates.md`:

1. The tasks are tickets under `.scratch/phase2-hybrid-dev/issues/` (Tasks 1-7 are tickets 02-08, Task 8a is ticket 09, Task 8b is ticket 10), with the blocking edges recorded in each ticket's `Blocked by:`.
2. Run them with **`/implement-spec`**: ready tickets on the frontier run in parallel, each in its own worktree with TDD, and are merged into one integration branch (`feature/phase2-hybrid-dev`), never directly into `develop` (AGENTS.md rule 1).
3. Before merging the integration branch to `develop`, it must pass the gates in decision 0003: superpowers `verification-before-completion`, gstack `/review`, and gstack `/cso --diff` (focus: secrets and `.env.local`).
4. Acceptance (Task 8b) is done by a fresh verifier session, with evidence under `docs/agent-workflow/evidence/phase2/`; the admin login is confirmed by the owner personally.
5. Nothing is pushed and no pull request is opened without the owner's explicit say-so (AGENTS.md rule 3).
