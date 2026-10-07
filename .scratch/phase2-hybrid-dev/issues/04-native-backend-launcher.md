# 04: Native backend launcher

**What to build:** A developer starts the backend natively with one command. The launcher takes the secrets from the existing Docker environment file without printing them, then overrides only the values that differ for host networking: database hosts to localhost, dashboard database port 5433, manager port 5432, Redis localhost port 6379, Qdrant URL localhost 6333, listening address localhost with `GIN_PORT=8088`, and `ORT_LIBRARY_PATH` pointing at the macOS library. If the library or the embedding model is missing it fails with a clear message before starting the backend. Implements plan Task 3.

**Blocked by:** 02 Make the ONNX Runtime library location configurable; 03 Publish host ports for postgres-data and redis.

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] Tests prove the launcher exports exactly the host-networking overrides listed above and nothing else new.
- [ ] A test proves secret values are never written to standard output or error.
- [ ] A test proves a missing library or model produces a clear error and a non-zero exit before the backend starts.
- [ ] The library default points at the location ticket 05 produces, with no code dependency on ticket 05.
- [ ] The launcher does not start any container and does not run `docker compose`.
- [ ] The change is committed in the worktree only.
