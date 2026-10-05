---
phase: 1
phase_name: "Local Docker deployment (learning baseline)"
project: "Taipei-City-Dashboard (local fork)"
generated: "2026-10-06"
counts:
  decisions: 7
  lessons: 7
  patterns: 5
  surprises: 6
missing_artifacts:
  - "*-PLAN.md / *-SUMMARY.md (GSD phase files; this project has no .planning/phases/ directory — superpowers plan and the executor ledger were used instead)"
  - "VERIFICATION.md / UAT.md (replaced by docs/agent-workflow/evidence/phase1-verification.md)"
  - "STATE.md (not initialised; GSD state update and estimate calibration were skipped)"
---

# Phase 1 Learnings: Local Docker deployment

Sources used: `docs/agent-workflow/evidence/phase1-verification.md` (E), `docs/decisions/0001-phase1-deploy-approach.md` (D), `docs/superpowers/plans/2026-10-06-phase1-local-deploy.md` (P), executor ledger `.superpowers/sdd/2026-10-06-phase1-local-deploy/progress.md` (L, git-ignored scratch).

## Decisions

### The BE embedding model is mandatory; there is no "plain golang image" fallback
The BE loads an ONNX embedding model and tokenizer at startup and exits via `log.Fatalf` if they are missing, even when no AI feature is used.

**Rationale:** `Taipei-City-Dashboard-BE/app/app.go:47` calls `InitLmSession()` unconditionally.
**Source:** D (ruling 1), L (Setup finding)

### Start only what Phase 1 needs
Run `redis postgres-data postgres-manager qdrant dashboard-fe dashboard-be`; skip nginx, pgAdmin and `vector-db-upgrade`.

**Rationale:** The FE is served by Vite on host port 8080 so nginx adds nothing locally; fewer containers on an 8.3 GB Docker VM; the vector upgrade job is only for AI search.
**Source:** D (rulings 3–5)

### Build the BE image separately before `up`
`docker compose build dashboard-be` first, then `up -d`.

**Rationale:** A failed multi-minute build should not leave a half-started stack.
**Source:** D (ruling 2), P Task 8

### Init is a one-shot action and is never re-run
**Rationale:** `initDashboard` loads sample data with `psql -f` and no `ON_ERROR_STOP`; re-running can duplicate or silently fail. Reset by deleting the two Postgres volumes.
**Source:** D (A8, A9), E §5

### Verify with row counts, not exit codes
**Rationale:** `app/initial/initial.go` swallows errors, so an init container can exit 0 without loading data.
**Source:** D (A8), P Task 7

### Code goes through a worktree; docs may go straight to `develop`
`make-env.sh` was built on `feature/make-env`; specs, plans, decision records and evidence were committed on `develop`.

**Rationale:** The spec's branch discipline; merging a feature branch is a shared-branch action gated on user approval.
**Source:** P Global Constraints, L (Task 5 ruling)

### Use `git add -f` for new shell scripts
**Rationale:** Upstream `.gitignore` line 29 ignores `*.sh`; editing it would add a needless fork divergence.
**Source:** L (Task 2 ruling), P Global Constraints

## Lessons

### A readiness probe must match the route exactly
`GET /api/v1/dashboard` returns 301; `GET /api/v1/dashboard/` returns 200. A loop waiting for 200 on the first would time out while the BE is healthy.
**Context:** Route is registered as `GET("/", ...)` under the `/dashboard` group (`router.go:137`). Confirmed empirically (301 vs 200).
**Source:** D (A1), E §2

### A log marker copied from memory can be wrong
The plan grepped for `Listening and serving HTTP`; this Gin build prints `... 0.0.0.0:8080` instead.
**Context:** Readiness was decided on the HTTP status instead.
**Source:** L (Task 8 ruling)

### Background tasks have a hard time limit; set the maximum for long builds
The first BE build was killed at 3600 s (my limit, below the 7200 s maximum) after the ~49-minute pip layer had finished.
**Context:** BuildKit kept the pip layer, so the rerun hit `CACHED` and finished in 559 s.
**Source:** L (Task 8 finding), E §6

### `task-done` from inside a worktree writes to the worktree's own ledger
**Context:** Run ledger scripts from the integration checkout (or merge the line by hand).
**Source:** L (Task 5 note)

### Guards that block reading `.env` also block leak-scans that read it
**Context:** A secret scan comparing doc text with `.env` values was refused. Replaced with an exact Mapbox-token match plus a scan for 16/24-hex strings (the shapes `make-env.sh` generates).
**Source:** L (Task 9 ruling), P Task 9 Step 3

### Silent `set -e` failures make weak RED tests
A test that exits silently because a script is missing does not prove it failed for the right reason; wrap the first call with `|| fail "<output>"`.
**Context:** Observed while writing `test-make-env.sh`.
**Source:** L (Task 5)

### A plan's own safety check can have false positives
The regex `pk\.[A-Za-z0-9._-]{20,}` flagged the test sentinel `pk.TESTSENTINEL…` inside the plan; an exact match on the real token value is stricter and prints nothing.
**Source:** L (Task 1 ruling)

## Patterns

### Ledger + task-done gate for inline execution
One ledger line per task, written only when a named check passes; rulings recorded in the same file.
**When to use:** Any multi-task inline plan where context may be compacted.
**Source:** L

### Tests that exercise the real template
`make-env.sh` has a test that runs against the real `docker/.env.template` and a test with a template missing keys.
**When to use:** Generators that depend on a file owned by upstream; catches key renames.
**Source:** D (Q1), P Task 5

### Atomic secret files
`os.open(..., O_CREAT|O_EXCL, 0o600)` plus a clean "refusing to overwrite" error (also for dangling symlinks).
**When to use:** Any script writing credentials to disk.
**Source:** L (Task 5 fixes)

### Evidence captured from live commands, not typed
The verification document's outputs were produced by running the commands in one shell block and embedding the results (that block was not committed, so the document shows outputs but not always the exact commands).
**When to use:** Acceptance records that must not drift from reality; commit the generating block next time.
**Source:** E

### Cheap probes before asking
Reading the router, the init code and the Dockerfile answered what the plan had assumed (health route, idempotency, image fallback).
**When to use:** Before committing a plan step that depends on third-party behaviour.
**Source:** D

## Surprises

### First BE build took over an hour of downloads
`pip install optimum[onnxruntime]` resolved CUDA-enabled PyTorch on aarch64 (multi-GB nvidia wheels at ~1.1–1.4 MB/s).
**Impact:** ~49 min for one layer. Only the converted model ends up in the final image, so it is build-time only; patching the Dockerfile (CPU-only torch) was judged not worth diverging from upstream.
**Source:** L (Task 8 finding), E §6

### The PostGIS image has no arm64 build
Both databases run under amd64 emulation on this Apple Silicon Mac.
**Impact:** Slower DB work; startup still fine. Upstream pins the tag.
**Source:** L (Task 6 finding), E §7

### Init containers exit 0 even when nothing was loaded (by design of the code)
**Impact:** Exit status is not evidence; row counts are.
**Source:** D (A8)

### Frontend sends analytics to the upstream city's Google Analytics ID from a local run
`Taipei-City-Dashboard-FE/index.html:31,39` loads Tag Manager with `G-0KD9XLZ7W3`.
**Impact:** Local browsing generates requests to someone else's GA property; candidate first customization.
**Source:** E §8

### New Kandev workspace gets the same task prefix as the existing one
Both are `KAN`; the prefix cannot be set at creation. Titles use `P1-xx` to stay unambiguous.
**Source:** L (Task 1 finding)

### Taipei dashboards API groups by audience
Unauthenticated `GET /api/v1/dashboard/` returns `public: 0, taipei: 2, metrotaipei: 3, personal: 0`, so "0 dashboards" in the public group is normal.
**Source:** E §2
