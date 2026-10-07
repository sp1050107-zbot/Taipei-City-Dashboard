# Phase 2 Hybrid Dev Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

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

- **FE dev proxy silently hits the real production site instead of the local BE.** `vite.config.js`'s non-Docker-Compose branch targets `https://citydashboard.taipei/api/v1`, not `localhost:8088`; a developer running `npm run dev` natively after this phase would edit the BE, see no change, and not know why. Pinned by Task 5's test (native mode must target `localhost:8088`).
- **A new FE `.env.local` holding the Mapbox token is not gitignored.** The repo's `.gitignore` only excludes `Taipei-City-Dashboard-FE/.env{,.development,.production,.test}` — `.env.local` (Vite's own local-override convention, which this plan introduces in Task 7) would slip through `git add` and leak the token on the first commit. Pinned by Task 6's test (must run *before* Task 7 creates the file).
- **The ONNX Runtime shared-library path is hardcoded to the Linux container path** (`app/models/qdrant.go:99`, `/usr/lib/libonnxruntime.so`). Native `go run` on macOS would call `log.Fatalf` on startup (AGENTS.md rule 5 behavior) with no way to point it at a macOS `.dylib`. Pinned by Task 1's test (env override must work).
- **postgres-data and redis have no host port mapping.** Only postgres-manager (`5432:5432`) and qdrant are reachable from the host; a natively-running BE would hang or connection-refuse against the other two. Pinned by Task 2's test (compose file must publish both ports) and Task 3's test (native launcher must point at them).
- **FE `node_modules` currently contains musl-linked native binaries** written by the Alpine-based init container (`docker-compose-init.yaml`'s `npm ci`, documented as B12 in `docs/agent-workflow/phase1-issue-log.md`). `npm run dev` on macOS against those binaries fails (wrong-platform native module). No unit test applies here (it's an OS/filesystem state, not code); pinned instead as an explicit, verifiable step in Task 8's runbook.

---

## File Structure

- `Taipei-City-Dashboard-BE/global/global.go` — modify: add `SharedLibraryPath` to `LMConfig`, sourced from `ORT_LIBRARY_PATH`.
- `Taipei-City-Dashboard-BE/global/global_test.go` — create: pins the new config field's default/override behavior.
- `Taipei-City-Dashboard-BE/app/models/qdrant.go` — modify: use `global.LM.SharedLibraryPath` instead of the hardcoded path.
- `docker/docker-compose-db.yaml` — modify: publish host ports for `postgres-data` (5433) and `redis` (6379).
- `docker/test-docker-compose-db.py` — create: asserts those port mappings exist (and that postgres-manager's didn't change).
- `Taipei-City-Dashboard-BE/dev-native.sh` — create: launches `go run main.go` with host-mode env overrides layered on top of the real `docker/.env`.
- `Taipei-City-Dashboard-BE/test-dev-native.sh` — create: asserts the overrides using a fixture env file and a stub `go`, never touching the real secret file.
- `Taipei-City-Dashboard-BE/setup-native-model.sh` — create: idempotently fetches the macOS ONNX Runtime library and copies the exported model out of the already-built `dashboard-be` container.
- `Taipei-City-Dashboard-BE/test-setup-native-model.sh` — create: asserts the idempotent skip path never shells out to `curl`/`docker` when the files already exist.
- `Taipei-City-Dashboard-FE/vite.server-config.js` — create: pure function resolving the dev-server `host`/`port`/`proxy` config from env, extracted so it's unit-testable without booting Vite.
- `Taipei-City-Dashboard-FE/vite.config.js` — modify: delegate to `resolveServerConfig`.
- `Taipei-City-Dashboard-FE/vite.server-config.test.mjs` — create: covers all four modes (compose / native-default / native-override / explicit-production).
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

```go
// Taipei-City-Dashboard-BE/global/global_test.go
package global

import "testing"

func TestLMConfigSharedLibraryPathDefault(t *testing.T) {
	cfg := LMConfig{SharedLibraryPath: getEnv("ORT_LIBRARY_PATH", "/usr/lib/libonnxruntime.so")}
	if cfg.SharedLibraryPath != "/usr/lib/libonnxruntime.so" {
		t.Fatalf("default SharedLibraryPath = %q, want /usr/lib/libonnxruntime.so", cfg.SharedLibraryPath)
	}
}

func TestLMConfigSharedLibraryPathOverride(t *testing.T) {
	t.Setenv("ORT_LIBRARY_PATH", "/opt/homebrew/lib/libonnxruntime.dylib")
	cfg := LMConfig{SharedLibraryPath: getEnv("ORT_LIBRARY_PATH", "/usr/lib/libonnxruntime.so")}
	if cfg.SharedLibraryPath != "/opt/homebrew/lib/libonnxruntime.dylib" {
		t.Fatalf("overridden SharedLibraryPath = %q, want /opt/homebrew/lib/libonnxruntime.dylib", cfg.SharedLibraryPath)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Taipei-City-Dashboard-BE && go test ./global/... -run TestLMConfigSharedLibraryPath -v`
Expected: build failure — `unknown field SharedLibraryPath in struct literal of type LMConfig` (the field doesn't exist yet).

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
Expected: `PASS` for both `TestLMConfigSharedLibraryPathDefault` and `TestLMConfigSharedLibraryPathOverride`.

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
- Produces: a `go run main.go` invocation with `DB_DASHBOARD_HOST=localhost`, `DB_DASHBOARD_PORT=5433`, `DB_MANAGER_HOST=localhost`, `REDIS_HOST=localhost`, `REDIS_PORT=6379`, `QDRANT_URL=http://localhost:6333`, `GIN_DOMAIN=localhost` — consumed by Task 8's runbook.

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
- Test: `Taipei-City-Dashboard-BE/test-setup-native-model.sh`

**Interfaces:**
- Produces: `Taipei-City-Dashboard-BE/onnxruntime/lib/libonnxruntime.dylib` and `Taipei-City-Dashboard-BE/lm_model/onnx-e5/model.onnx` — both already covered by `Taipei-City-Dashboard-BE/.gitignore`'s existing `lm_model`/`onnxruntime` entries. Consumed by Task 3's `dev-native.sh` defaults.

- [ ] **Step 1: Write the failing test (idempotency)**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/test-setup-native-model.sh
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp setup-native-model.sh "$WORK/"
cd "$WORK"

mkdir -p onnxruntime/lib lm_model/onnx-e5
touch onnxruntime/lib/libonnxruntime.dylib
touch lm_model/onnx-e5/model.onnx

mkdir -p bin
cat > bin/curl <<'EOF'
#!/usr/bin/env bash
echo "curl must not run when onnxruntime is already installed" >&2
exit 1
EOF
cat > bin/docker <<'EOF'
#!/usr/bin/env bash
echo "docker must not run when the model is already exported" >&2
exit 1
EOF
chmod +x bin/curl bin/docker

PATH="$(pwd)/bin:$PATH" CURL_BIN=curl DOCKER_BIN=docker ./setup-native-model.sh
echo "PASS (idempotent skip verified)"
```

- [ ] **Step 2: Write a naive (unconditional) first version and confirm RED**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/setup-native-model.sh (naive first draft)
set -euo pipefail
cd "$(dirname "$0")"

ORT_VERSION="1.23.2"
ARCH="${NATIVE_ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64) ORT_ASSET="onnxruntime-osx-arm64-${ORT_VERSION}.tgz" ;;
  x86_64) ORT_ASSET="onnxruntime-osx-x86_64-${ORT_VERSION}.tgz" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac

mkdir -p onnxruntime
URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_ASSET}"
"${CURL_BIN:-curl}" -fL "$URL" -o /tmp/ort.tgz
tar -xzf /tmp/ort.tgz -C onnxruntime --strip-components=1
rm -f /tmp/ort.tgz

mkdir -p lm_model/onnx-e5
"${DOCKER_BIN:-docker}" cp dashboard-be:/opt/lm_model/onnx-e5/. lm_model/onnx-e5/
```

Run: `chmod +x Taipei-City-Dashboard-BE/setup-native-model.sh Taipei-City-Dashboard-BE/test-setup-native-model.sh && Taipei-City-Dashboard-BE/test-setup-native-model.sh`
Expected: `FAIL` — the stub `curl` exits 1 with `curl must not run when onnxruntime is already installed`, because the naive script calls it unconditionally.

- [ ] **Step 3: Add idempotency guards**

```bash
#!/usr/bin/env bash
# Taipei-City-Dashboard-BE/setup-native-model.sh
# Phase 2 hybrid dev: fetch the macOS ONNX Runtime library and the exported
# e5 model out of the already-built dashboard-be-dev:latest image, so native
# `go run` has what the container build produced without re-running the
# Python export pipeline on the host.
set -euo pipefail
cd "$(dirname "$0")"

ORT_VERSION="1.23.2"
ORT_LIB="onnxruntime/lib/libonnxruntime.dylib"
MODEL_FILE="lm_model/onnx-e5/model.onnx"

ARCH="${NATIVE_ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64) ORT_ASSET="onnxruntime-osx-arm64-${ORT_VERSION}.tgz" ;;
  x86_64) ORT_ASSET="onnxruntime-osx-x86_64-${ORT_VERSION}.tgz" ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
esac

if [ -f "$ORT_LIB" ]; then
  echo "onnxruntime already installed at $ORT_LIB"
else
  mkdir -p onnxruntime
  URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_ASSET}"
  "${CURL_BIN:-curl}" -fL "$URL" -o /tmp/ort.tgz
  tar -xzf /tmp/ort.tgz -C onnxruntime --strip-components=1
  rm -f /tmp/ort.tgz
  echo "installed onnxruntime -> $ORT_LIB"
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
Expected: `PASS (idempotent skip verified)`.

- [ ] **Step 5: Commit**

```bash
git add -f Taipei-City-Dashboard-BE/setup-native-model.sh Taipei-City-Dashboard-BE/test-setup-native-model.sh
git commit -m "feat(be): add idempotent macOS onnxruntime+model setup for native dev"
```

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

// Docker Compose mode (Phase 1): proxy to the container's BE by name, port 80 (host remaps to 8080).
{
	const cfg = resolveServerConfig({ DOCKER_COMPOSE: "true" });
	assert.equal(cfg.port, 80);
	assert.equal(cfg.proxy["/api/dev"].target, "http://dashboard-be:8080");
}

// Native host dev (Phase 2 default): proxy to the native BE on localhost, port 8080 (no root needed).
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

// Explicit opt-in to the upstream production backend (pre-existing behavior, now opt-in only).
{
	const cfg = resolveServerConfig({ VITE_DEV_BACKEND: "production" });
	assert.equal(cfg.port, 8080);
	assert.equal(cfg.proxy["/api"].target, "https://citydashboard.taipei/api/v1");
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
	const useRemoteBackend = env.VITE_DEV_BACKEND === "production";

	if (isDockerCompose) {
		return {
			host: "0.0.0.0",
			port: 80,
			proxy: {
				"/api/dev": {
					target: "http://dashboard-be:8080",
					changeOrigin: true,
					rewrite: (path) => path.replace("/dev", "/v1"),
				},
			},
		};
	}

	if (useRemoteBackend) {
		return {
			host: "0.0.0.0",
			port: 8080,
			proxy: {
				"/api": {
					target: "https://citydashboard.taipei/api/v1",
					changeOrigin: true,
					rewrite: (path) => path.replace(/^\/api/, ""),
				},
				"/geo_server": {
					target: "https://citydashboard.taipei/geo_server/",
					changeOrigin: true,
					rewrite: (path) => path.replace(/^\/geo_server/, ""),
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

### Task 8: End-to-end native dev runbook and acceptance evidence

**Depends on:** Tasks 1-7, plus the Phase 1 stack's DB containers already initialized (per `.planning/HANDOFF-phase1.md` — init is one-shot, do not rerun it).

**Files:**
- Create: `docs/agent-workflow/evidence/phase2-verification.md` (evidence only; no code)

This task has no unit test of its own — Task 1-7's tests cover the code; this is the runbook that proves the *system* meets spec §1 success criterion 2. Run every step for real and paste actual output into the evidence file (per superpowers:verification-before-completion).

- [ ] **Step 1: Apply Task 2's compose change in the integration checkout**

In `~/Taipei-City-Dashboard/docker` (not this worktree — AGENTS.md rule 7):
```bash
docker compose -f docker-compose-db.yaml up -d
docker compose -f docker-compose-db.yaml ps
```
Expected: `postgres-data`, `postgres-manager`, `redis`, `qdrant` all `running`; `docker port postgres-data` shows `5432/tcp -> 0.0.0.0:5433`; `docker port redis` shows `6379/tcp -> 0.0.0.0:6379`.

- [ ] **Step 2: Stop the containerized FE/BE (keep DB/Redis/Qdrant up)**

```bash
docker compose -f docker-compose.yaml stop dashboard-fe dashboard-be
```
Expected: both containers `Exited`; the four infra containers from Step 1 stay `running`.

- [ ] **Step 3: Set up the BE's native runtime**

```bash
cd Taipei-City-Dashboard-BE
./setup-native-model.sh
```
Expected: `installed onnxruntime -> onnxruntime/lib/libonnxruntime.dylib` and `copied model -> lm_model/onnx-e5/model.onnx` (first run); `already installed`/`already exported` on reruns.

- [ ] **Step 4: Run the BE natively**

```bash
./dev-native.sh
```
Expected: process logs the embedding model loading successfully (no `log.Fatalf`), then Gin listening on `localhost:8080` (per `GIN_PORT` default) — confirm with `curl -i http://localhost:8080/api/v1/dashboard/` (trailing slash — see `docs/decisions/0001-phase1-deploy-approach.md` ruling 6) returning `200`.

- [ ] **Step 5: Reinstall FE node_modules natively (clears the musl binaries from the Alpine init container — B12)**

```bash
cd ../Taipei-City-Dashboard-FE
rm -rf node_modules package-lock.json
npm install
```
Expected: install completes with no `invalid ELF header` or platform-mismatch errors on the subsequent `npm run dev`.

- [ ] **Step 6: Generate the FE's local env and run it natively**

```bash
./make-dev-env.sh
npm run dev
```
Expected: Vite dev server on `http://localhost:8080` (per Task 5's `resolveServerConfig` default); opening it in a browser shows the dashboard with map tiles (Mapbox token from `.env.local`); network tab shows `/api/dev/...` requests resolving against `localhost:8088`'s equivalent (`localhost:8080` per Step 4 — adjust `GIN_PORT`/`VITE_LOCAL_BE_URL` to match whichever port the native BE actually bound, and record the exact value used here).

- [ ] **Step 7: Prove the hot-loop (spec §1 success criterion 2)**

Change one line in `Taipei-City-Dashboard-FE/src/` (e.g. a label string) and one line in `Taipei-City-Dashboard-BE/app/controllers/` (e.g. a log message) while both dev processes are running. Expected: the FE change appears in the browser via Vite HMR within ~1 second with no manual reload; the BE change requires killing/rerunning `./dev-native.sh` (plain `go run`, no hot-reload) but recompiles and is live within a few seconds — record the actual wall-clock time observed.

- [ ] **Step 8: Confirm debugger attach**

For the BE: open `Taipei-City-Dashboard-BE` in VS Code or GoLand, set a breakpoint in a controller, launch via "Run and Debug" (uses `dlv` under the hood) instead of `./dev-native.sh`, hit the endpoint, confirm the breakpoint pauses execution. For the FE: open the browser's DevTools, set a breakpoint in a `.vue` file under Sources (Vite serves real source maps), confirm it pauses. Record which IDE/tool was used and that both breakpoints were hit.

- [ ] **Step 9: Write the evidence file and commit**

Write `docs/agent-workflow/evidence/phase2-verification.md` with the real command output from Steps 1-8 (ports, curl status codes, HMR timing, debugger screenshots or descriptions — no secrets).

```bash
git add docs/agent-workflow/evidence/phase2-verification.md
git commit -m "docs: record Phase 2 hybrid-dev verification evidence"
```

---

## Self-Review

**Spec coverage:** §1 success criterion 2 (edit FE/BE, see it in seconds, debugger works) → Task 8 end-to-end. §7 "Docker 只留 postgres-data、postgres-manager、redis（必要時 qdrant）；FE `npm run dev`、BE `go run`" → Tasks 1-5 (code) + Task 8 (runbook). §7 "改 env 的 host 為 localhost，確認各 DB 埠有對外映射" → Tasks 2-3. §7 "風險：onnxruntime 在 Apple Silicon 原生執行" → Tasks 1 and 4 (this plan treats it as solvable via a configurable library path + a macOS binary fetch, not as an open risk anymore — Task 8 Step 4 is where that gets proven or disproven for real). §7 "這些變更屬 compose/設定變更，走 worktree 流程" → Global Constraints. §7 optional "TCD-B1 MapLibre + OpenFreeMap" and issue-log B27 (GA tracking removal) are **explicitly out of scope** for this plan — spec §7 itself calls MapLibre "選配，由使用者決定是否做"; neither blocks the hybrid-dev goal, so they stay separate future `B 客製開發` tasks.

**Placeholder scan:** none found — every step has runnable code/commands and concrete expected output.

**Type consistency:** `global.LM.SharedLibraryPath` (Task 1) is the only new Go identifier and it's used identically in `global.go` and `qdrant.go`. `resolveServerConfig(env)` (Task 5) has one signature used identically in the test and in `vite.config.js`. `ORT_LIBRARY_PATH`, `LM_MODEL_PATH`, `DEV_NATIVE_ENV_FILE` (Tasks 1/3/4) are used with the same names and defaults across the scripts that produce and consume them.

**Review Focus:** all five items listed above have an owning task and a test (four unit/integration tests, one explicit runbook step for the one OS-state issue that isn't code). No additional gaps found.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md`. Please review the plan. Which execution approach would you prefer?

- **Subagent-driven** — a fresh subagent implements each task and a fresh reviewer checks it before the next one starts, then a whole-branch review at the end. Most thorough; costs a fresh context per task and per review.
- **Native** — I implement every task myself in this session, the way this harness runs work, then one fresh reviewer on the most capable model checks the whole branch. Cheapest and fastest; no independent review until the end.

For this plan I recommend **Subagent-driven**, because Tasks 1-7 are mostly independent (different files, different languages — Go, YAML, bash, JS) but Task 8 depends on all of them being correct at once, and a shipped mistake here (e.g. the FE proxy still silently hitting production, or the `.env.local` gitignore gap) is exactly the kind of thing that's invisible until someone's token leaks or they waste an hour debugging a "BE change that didn't show up." Does the plan capture what you want, and which approach should we use?
