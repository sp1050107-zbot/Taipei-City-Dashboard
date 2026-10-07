# 03: Publish host ports for postgres-data and redis

**What to build:** A natively running backend can reach the dashboard database and Redis: `postgres-data` is published on host port 5433 and `redis` on host port 6379, while `postgres-manager` keeps 5432. This ticket only changes the compose definition and its test; it does not run `docker compose` (applying it is ticket 09). Implements plan Task 2.

**Blocked by:** None (can start immediately, after the P2-00 branch has been merged to `develop`).

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] A test fails while either mapping is missing and passes once both exist.
- [x] Both containers keep their volumes and container names unchanged.
- [x] The published ports are harmless to Phase 1 (no service that works today stops working).
- [x] `docker compose` is not executed anywhere in this ticket.
- [x] The change is committed in the worktree only.

## Answer

Commit: see `git log -1` on branch feature/phase2-03 (sha recorded in the hand-off report; a commit cannot contain its own sha).

- `docker/docker-compose-db.yaml`: `redis` publishes `6379:6379`, `postgres-data` publishes `5433:5432`; `postgres-manager` still `5432:5432`. Volumes and container names untouched.
- `docker/test-docker-compose-db.py` (stdlib only, plain text matching). RED before the change: `AssertionError: postgres-data must publish host port 5433 -> 5432`. GREEN after: `PASS` (4 checks: both new mappings, manager unchanged, volumes and container names unchanged).
- Phase 1 harm check: no other compose file in `docker/` maps host 5433 or 6379. UNVERIFIED: whether something on the owner's host already listens on 5433/6379 (applying the change is ticket 09).
- `docker compose` was not executed.
