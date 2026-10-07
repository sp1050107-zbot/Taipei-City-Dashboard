# 03: Publish host ports for postgres-data and redis

**What to build:** A natively running backend can reach the dashboard database and Redis: `postgres-data` is published on host port 5433 and `redis` on host port 6379, while `postgres-manager` keeps 5432. This ticket only changes the compose definition and its test; it does not run `docker compose` (applying it is ticket 09). Implements plan Task 2.

**Blocked by:** None (can start immediately, after the P2-00 branch has been merged to `develop`).

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] A test fails while either mapping is missing and passes once both exist.
- [ ] Both containers keep their volumes and container names unchanged.
- [ ] The published ports are harmless to Phase 1 (no service that works today stops working).
- [ ] `docker compose` is not executed anywhere in this ticket.
- [ ] The change is committed in the worktree only.
