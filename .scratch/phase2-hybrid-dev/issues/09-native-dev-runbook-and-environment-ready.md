# 09: Native dev runbook and environment ready

**What to build:** The hybrid stack is ready to verify: a runbook exists and the environment has been brought up. The runbook covers starting Phase 2, the rule that only one of Phase 1 or Phase 2 runs at a time, the return-to-Phase-1 section, and recording HMR and restart timings. Bringing the environment up stops the Phase 1 frontend and backend containers, recreates the `postgres-data` and `redis` containers with the new ports (volumes kept, no initialisation rerun), installs Node 21, and reinstalls frontend dependencies on the host. Implements the first half of plan Task 8 as revised by ticket 01.

**Blocked by:** 02, 03, 04, 05, 06, 07, 08, 11 (all merged to develop via the integration branch).

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] **Ask the owner and wait for approval before recreating the `postgres-data` and `redis` containers**; volumes are kept and initialisation is not rerun (AGENTS.md rule 9). This is done in the integration checkout only.
- [x] **Ask the owner and wait for approval before installing Node 21**, then pin the frontend to Node 21 and use the local Go toolchain for the backend.
- [x] The Phase 1 `dashboard-fe` and `dashboard-be` containers are stopped; `postgres-manager`, `postgres-data`, `redis` and `qdrant` stay up.
- [x] Frontend dependencies are reinstalled on the host so the Alpine-built binaries are replaced.
- [ ] The runbook contains a working return-to-Phase-1 section (stop the native processes, restart the two containers, probe succeeds) and a one-stack-at-a-time statement matching decision 0002.
- [x] The runbook uses frontend 8080 and backend 8088 everywhere.
- [x] Every claim in the runbook has a command and its output stored under the Phase 2 evidence folder.
- [x] The runbook change is committed in the worktree only; nothing is pushed.

## Answer

Environment is up: Phase 1 `dashboard-fe` and `dashboard-be` stopped (not removed), `redis` and `postgres-data` recreated on `127.0.0.1:6379` and `127.0.0.1:5433` with volumes kept, ONNX Runtime 1.23.2 installed (owner-approved download, SHA256 `b4d513ab…7856` verified, 9.5 MB), the embedding model copied from `dashboard-be-dev:latest`, Node v21.7.3 installed under the user directory (owner-approved, SHA256 verified), frontend dependencies reinstalled with `npm ci` (owner-approved), the frontend local env file generated from the owner's key file (not printed, ignored by git), native backend and native frontend running (8088 / 8080).

Commits: runbook `fe261559`, pinned digest `9a9d20c0`, extraction fix `e86adf8c` (merge `7a67a189`), env-file inline comment fix `0ce3f418` (merge `f52f3528`). Evidence: `docs/agent-workflow/evidence/phase2/09-environment.log`.

Two real defects were found by running the real thing, which stub tests had not shown, and fixed test-first: the release archive layout (the script reported success with the library one level too deep) and inline comments in the Docker env file (`GIN_MODE=debug # …` made Gin panic).

Left unticked on purpose: the return-to-Phase-1 section is written but not yet executed; ticket 10 must run it. Open UNVERIFIED items go to ticket 10: `POST /component` behaviour, admin login (owner), debugger breakpoints, `/geo_server` map layers, `REDIS_PASSWORD` match, `gtfs_bundle` warning being pre-existing.

