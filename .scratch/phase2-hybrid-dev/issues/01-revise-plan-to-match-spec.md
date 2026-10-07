# 01: Revise the Phase 2 plan to match the spec

**What to build:** The Phase 2 plan matches the spec: the four known gaps recorded in the spec's Further Notes are closed, so every later ticket can follow the plan without contradicting the spec. This is a documentation change only.

**Blocked by:** None (can start immediately, after the P2-00 branch has been merged to `develop`).

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] Plan Task 4 requires SHA256 verification of the downloaded ONNX Runtime 1.23.2 archive before use, and requires the script to stop and ask the owner before any download (spec user stories 14, 15).
- [x] The plan states that Task 3's launcher uses the library location Task 4 produces only as a default value, with no code dependency between them, and that Task 8's end-to-end check must confirm both are in place.
- [x] Every port mention in the plan uses frontend 8080 and backend 8088 consistently (decision 0002); no sentence mixes 8080 and 8088 for the backend.
- [x] Plan Task 1's test is rewritten to go through the real configuration reader so it can fail for the right reason, not rebuild the value itself.
- [x] The plan's Task 8 is split to match tickets 09 and 10 (runbook and environment readiness, then acceptance by a fresh verifier session).
- [x] The plan's execution handoff section points to `/implement-spec` and the gates in decision 0003 instead of asking Subagent-driven versus Native.
- [x] A documentation check passes and no secret appears in the diff.

## Answer

Resolved in one docs commit on `feature/phase2-01` (subject: `docs(plan): revise Phase 2 plan to match spec`; the sha is in `git log`). Only `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` and this ticket changed.

What changed in the plan:
- Task 4: owner-approval gate (`ORT_DOWNLOAD_APPROVED=yes`, file name and source printed, no network call otherwise) and SHA256 gate (`onnxruntime.sha256`, mismatch extracts nothing); arm64 only. The new test was extracted from the plan and run against the plan's script in a scratch sandbox with stubs: `PASS (idempotent skip, approval gate, SHA256 gate verified)`.
- Task 3 states it has no code dependency on Task 4 (library and model paths are defaults only); Tasks 8a/8b Step 6 / Step 1 check both are in place. Launcher now also exports `GIN_PORT=8088`.
- Ports: frontend 8080, backend 8088 everywhere; the one remaining `dashboard-be:8080` is the Phase 1 container-internal port and is labelled as such.
- Task 1 test now loads the real package-level configuration in a child process instead of rebuilding the value with `getEnv`.
- Task 8 split into 8a (runbook and environment ready, ticket 09) and 8b (fresh-verifier acceptance, ticket 10).
- Execution Handoff now points to `/implement-spec` and the decision 0003 gates.

Evidence:
- `bash docs/agent-workflow/check-docs.sh` -> `PASS`
- Secret pattern scan of `git diff` (`pk.` / `sk-` token shapes) -> no matches. The literal Mapbox token comparison was not run because the key file must not be read; UNVERIFIED beyond the pattern scan.
- UNVERIFIED: the new Task 1 Go test was not compiled or run (the plan only; no code was changed in this ticket).
