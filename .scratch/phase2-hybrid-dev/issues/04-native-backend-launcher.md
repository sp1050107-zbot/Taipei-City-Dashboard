# 04: Native backend launcher

**What to build:** A developer starts the backend natively with one command. The launcher takes the secrets from the existing Docker environment file without printing them, then overrides only the values that differ for host networking: database hosts to localhost, dashboard database port 5433, manager port 5432, Redis localhost port 6379, Qdrant URL localhost 6333, listening address localhost with `GIN_PORT=8088`, and `ORT_LIBRARY_PATH` pointing at the macOS library. If the library or the embedding model is missing it fails with a clear message before starting the backend. Implements plan Task 3.

**Blocked by:** 02 Make the ONNX Runtime library location configurable; 03 Publish host ports for postgres-data and redis.

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] Tests prove the launcher exports exactly the host-networking overrides listed above and nothing else new.
- [x] A test proves secret values are never written to standard output or error.
- [x] A test proves a missing library or model produces a clear error and a non-zero exit before the backend starts.
- [x] The library default points at the location ticket 05 produces, with no code dependency on ticket 05.
- [x] The launcher does not start any container and does not run `docker compose`.
- [x] The change is committed in the worktree only.

## Answer

Added `Taipei-City-Dashboard-BE/dev-native.sh` and its test `Taipei-City-Dashboard-BE/test-dev-native.sh` (commit `4f6b3214`). Run the test with `Taipei-City-Dashboard-BE/test-dev-native.sh`; it uses a fake env file with sentinel values and a stub `go`, so no real backend, compile, Docker env file or container is involved.

- Overrides: DB hosts localhost, dashboard port 5433, manager port 5432, Redis localhost:6379, Qdrant `http://localhost:6333`, `GIN_DOMAIN=localhost`, `GIN_PORT=8088`, `ORT_LIBRARY_PATH`, `LM_MODEL_PATH` (defaults `onnxruntime/lib/libonnxruntime.dylib`, `lm_model/onnx-e5/`), plus `GOTOOLCHAIN=local`. The test checks the set of newly introduced variable names is exactly that.
- Secrets: sentinel values never appear in stdout or stderr on success or failure (a mutant that echoed the secret made the test fail).
- Missing library or model: clear message naming the path, exit 1, stub `go` never invoked.
- No code dependency on ticket 05; the launcher contains no docker command (test greps for it).
- Scripts are force-added (`git add -f`) because upstream ignores `*.sh`.
- UNVERIFIED: running against the real Docker env file and the real backend (ONNX Runtime and the model are not on this machine).
