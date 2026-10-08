# 06: Frontend dev proxy defaults to the local backend

**What to build:** A developer running the frontend natively never silently hits the production site. In native mode the `/api/dev` proxy targets the local backend by default (`http://localhost:8088`), overridable with `VITE_LOCAL_BE_URL`; container-mode behaviour is unchanged. The proxy configuration is extracted so a test can check it. Implements plan Task 5.

**Blocked by:** None (can start immediately, after the P2-00 branch has been merged to `develop`).

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] A test fails if native mode targets the production site and passes with the local default.
- [x] A test proves `VITE_LOCAL_BE_URL` overrides the default.
- [x] A test proves container-mode proxy settings are unchanged.
- [x] The frontend dev server is configured for host port 8080 in native mode (spec: frontend 8080, backend 8088).
- [x] The change is committed in the worktree only.

## Answer

Commit: `421eb701`.

- RED: `node Taipei-City-Dashboard-FE/vite.server-config.test.mjs` -> `ERR_MODULE_NOT_FOUND: Cannot find module .../vite.server-config.js`.
- GREEN: same command -> `PASS` (container mode unchanged incl. rewrite `/api/dev/x` -> `/api/v1/x`; native default target `http://localhost:8088`, port 8080, no `citydashboard.taipei` anywhere; `VITE_LOCAL_BE_URL` override honoured).
- Native mode no longer has a production proxy or an opt-in for it (plan's `VITE_DEV_BACKEND=production` branch was dropped as outside the ticket); `/geo_server` is no longer proxied in native mode.
- UNVERIFIED: `npm run build` / lint and the Vite dev server actually binding 8080 (no node_modules in worktree; not run). Port 8080 is proven only at the config-function level.
