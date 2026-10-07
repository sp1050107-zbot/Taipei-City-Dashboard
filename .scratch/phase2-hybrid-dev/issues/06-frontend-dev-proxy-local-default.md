# 06: Frontend dev proxy defaults to the local backend

**What to build:** A developer running the frontend natively never silently hits the production site. In native mode the `/api/dev` proxy targets the local backend by default (`http://localhost:8088`), overridable with `VITE_LOCAL_BE_URL`; container-mode behaviour is unchanged. The proxy configuration is extracted so a test can check it. Implements plan Task 5.

**Blocked by:** None (can start immediately, after the P2-00 branch has been merged to `develop`).

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] A test fails if native mode targets the production site and passes with the local default.
- [ ] A test proves `VITE_LOCAL_BE_URL` overrides the default.
- [ ] A test proves container-mode proxy settings are unchanged.
- [ ] The frontend dev server is configured for host port 8080 in native mode (spec: frontend 8080, backend 8088).
- [ ] The change is committed in the worktree only.
