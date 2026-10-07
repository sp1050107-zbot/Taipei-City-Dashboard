# 10: Phase 2 acceptance by a fresh verifier session

**What to build:** An independent verdict on Phase 2. A fresh session (not the implementer) runs the acceptance checklist from the spec against the running hybrid stack and stores the evidence under `docs/agent-workflow/evidence/phase2/`. Implements the second half of plan Task 8 as revised by ticket 01.

**Blocked by:** 09 Native dev runbook and environment ready.

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] The verifier is a new session that did not implement any ticket 01 to 09.
- [ ] Backend starts natively and stays up (no fatal exit on ONNX Runtime or the embedding model); readiness probe on the backend dashboard route (with trailing slash) succeeds; databases and Redis connect.
- [ ] Frontend serves on 8080 and proxies to the local backend, not production.
- [ ] Dashboard page, map page and admin page load.
- [ ] Frontend HMR time and backend restart time are measured and recorded as numbers.
- [ ] A breakpoint is hit on the frontend and on the backend; the tool used is recorded.
- [ ] The return-to-Phase-1 section is executed and works.
- [ ] A secret scan of all staged changes is clean and the frontend local environment file is ignored by git.
- [ ] **Admin login is confirmed by the owner personally; no agent logs in or reads the admin password.** Until the owner reports, this item is UNVERIFIED.
- [ ] Every UNVERIFIED item from the spec is either proven with command output or left explicitly marked UNVERIFIED with the reason, including: ONNX Runtime 1.23.2 compatibility, host Go build, Node 21 install, `.env.local` non-leak, and the status code of `POST /component` when the Qdrant collection is missing.
- [ ] No code is changed by this ticket; findings that need a fix become new tickets.
