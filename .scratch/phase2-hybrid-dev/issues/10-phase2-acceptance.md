# 10: Phase 2 acceptance by a fresh verifier session

**What to build:** An independent verdict on Phase 2. A fresh session (not the implementer) runs the acceptance checklist from the spec against the running hybrid stack and stores the evidence under `docs/agent-workflow/evidence/phase2/`. Implements the second half of plan Task 8 as revised by ticket 01.

**Blocked by:** 09 Native dev runbook and environment ready.

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] The verifier is a new session that did not implement any ticket 01 to 09.
- [x] Backend starts natively and stays up (no fatal exit on ONNX Runtime or the embedding model); readiness probe on the backend dashboard route (with trailing slash) succeeds; databases and Redis connect.
- [x] Frontend serves on 8080 and proxies to the local backend, not production.
- [x] Dashboard page, map page and admin page load. (Admin page: shown by the owner's screenshot on 2026-10-09, see below.)
- [x] Frontend HMR time and backend restart time are measured and recorded as numbers.
- [x] A breakpoint is hit on the frontend and on the backend; the tool used is recorded. Backend: hit with Delve 1.27.2 headless on 2026-10-10 (`evidence/phase2/10-backend-breakpoint-dlv.md`); frontend: verified by the owner on 2026-10-10 in Chrome DevTools Sources at `src/store/contentStore.js:137`.
- [x] The return-to-Phase-1 section is executed and works (2026-10-09, owner approved; evidence `docs/agent-workflow/evidence/phase2/10-return-to-phase1.md`).
- [x] A secret scan of all staged changes is clean and the frontend local environment file is ignored by git.
- [x] **Admin login is confirmed by the owner personally; no agent logs in or reads the admin password.** Until the owner reports, this item is UNVERIFIED. Confirmed 2026-10-09 by the owner's screenshot, on the Phase 1 container stack (same databases and same backend code); not repeated on the native stack.
- [x] Every UNVERIFIED item from the spec is either proven with command output or left explicitly marked UNVERIFIED with the reason, including: ONNX Runtime 1.23.2 compatibility, host Go build, Node 21 install, `.env.local` non-leak, and the status code of `POST /component` when the Qdrant collection is missing.
- [x] No code is changed by this ticket; findings that need a fix become new tickets.

## Answer

Verdict of the fresh verifier session: **ACCEPTED WITH UNVERIFIED ITEMS**. Nothing failed. The ticket stays `claimed` until the owner does the open steps below. Report and screenshots: `docs/agent-workflow/evidence/phase2/10-acceptance.md`.

Proven: backend stays up and answers the readiness probe (200) with both databases and Redis connected and no fatal exit on ONNX Runtime or the model; frontend on 8080 proxies to the local backend (identical body to the backend's own route, nothing points at the production site); dashboard page renders with no console errors; map page renders; HMR push measured at 12, 17 and 103 ms (server push only, not browser repaint); backend restart 1.15 to 1.78 s with a warm Go build cache; working tree clean, local env file, `onnxruntime`, `lm_model` and `node_modules` ignored; ONNX Runtime 1.23.2 with the project's Go binding, host Go 1.27.1, Node 21.7.3 and `npm ci` all worked in practice; `POST /api/v1/vector/component` without a Qdrant collection returned 404 and `POST /api/v1/component/` returned 403 unauthenticated; the `gtfs_bundle` warning also appears in the Phase 1 backend logs, so it is not caused by Phase 2.

Open, left unticked on purpose (owner steps): the admin page was never seen (`/admin` redirects to the dashboard when not logged in), admin login, debugger breakpoints on both sides, and the return-to-Phase-1 section (needs the owner's approval because it runs the init container that downloads npm packages and replaces `node_modules`). `/geo_server/` requests did not happen while loading the map page, so whether the layers are blank is still UNVERIFIED.

Corrections made from the findings: the AI search route is `POST /api/v1/vector/component` (GLOSSARY, spec and runbook fixed); the runbook now states the measured timings and what they do and do not measure. Follow-ups, not fixed here: the missing Qdrant collection `query_charts` and the missing `gtfs_bundle` table exist in Phase 1 as well.

### Update 2026-10-09 (owner)

- Owner logged in as `admin` by Shift-clicking the TUIC logo in the login dialog (email and password mode) and opened `http://127.0.0.1:8080/admin/dashboard?city=taipei`. The admin console shows the sidebar (儀表板設定, 組件設定, 問題回報, 系統總覽), the user name `admin` in the header, and the 臺北儀表板 list with `map-layers-taipei` [217] and `ltc_care_tpe` [214, 215, 216, 218]. Evidence: `docs/agent-workflow/evidence/phase2/10-admin-dashboard-owner.webp`. The agent did not log in and did not read the password.
- This ran on the Phase 1 container stack, because the stack was returned to Phase 1 the same day (`evidence/phase2/10-return-to-phase1.md`). The native stack uses the same databases and the same backend code, but the login was not repeated there.
- Still open and unticked on purpose: debugger breakpoints on the frontend and on the backend (needs the native stack, `dlv`, and the owner's IDE and browser DevTools).

### Update 2026-10-09 (backend corroboration of the owner's admin login)

Checked by Claude from the Phase 1 backend container log and the manager database (read only; no password, hash, email or user name was read or printed): `POST /api/v1/auth/login` returned 200 at 23:37:27 UTC, followed by `GET /api/v1/user/me`, `GET /api/v1/user/1/viewpoint` and the dashboard chart requests, all 200; every request in the last 45 minutes returned 200. The manager database has exactly one user (id 1) with `is_admin = true`, `is_active = true`, `is_blacked = false`, and its `login_at` equals the login request time (23:37:27 UTC).

What this does not show: the log contains no admin-console API requests after the login (the last request was at 23:37:40 UTC), so the owner's screenshot is the only evidence that the `/admin` pages rendered. Debugger breakpoints are still open.

### Update 2026-10-10 (backend breakpoint)

- Backend breakpoint hit: Delve 1.27.2 headless, `GetAllDashboards` at `app/controllers/dashboard.go:24`, triggered by `GET /api/v1/dashboard/`; native backend restored afterwards. This proves Delve can attach, not that an IDE's Run and Debug works. Evidence: `docs/agent-workflow/evidence/phase2/10-backend-breakpoint-dlv.md`.
- Still open: frontend breakpoint (owner, Chrome DevTools).

### Update 2026-10-10 (frontend breakpoint, ticket resolved)

- Owner (大里) reported in chat on 2026-10-10: the frontend breakpoint was verified in Chrome DevTools Sources at `src/store/contentStore.js` line 137, ``const response = await http.get(`/dashboard/`);`` inside `setDashboards`, which runs on page load. That is the request the backend breakpoint caught in `GetAllDashboards`. The agent did not see it; this line records the owner's report.
- Every acceptance item is now ticked. Ticket resolved. Caveats that stay true: admin login was confirmed on the Phase 1 container stack, not repeated on the native stack; the backend breakpoint was hit with headless Delve, not through an IDE; `/geo_server/` behaviour is still UNVERIFIED (not an acceptance item).
