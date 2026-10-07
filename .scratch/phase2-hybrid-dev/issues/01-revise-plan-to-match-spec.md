# 01: Revise the Phase 2 plan to match the spec

**What to build:** The Phase 2 plan matches the spec: the four known gaps recorded in the spec's Further Notes are closed, so every later ticket can follow the plan without contradicting the spec. This is a documentation change only.

**Blocked by:** None (can start immediately, after the P2-00 branch has been merged to `develop`).

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] Plan Task 4 requires SHA256 verification of the downloaded ONNX Runtime 1.23.2 archive before use, and requires the script to stop and ask the owner before any download (spec user stories 14, 15).
- [ ] The plan states that Task 3's launcher uses the library location Task 4 produces only as a default value, with no code dependency between them, and that Task 8's end-to-end check must confirm both are in place.
- [ ] Every port mention in the plan uses frontend 8080 and backend 8088 consistently (decision 0002); no sentence mixes 8080 and 8088 for the backend.
- [ ] Plan Task 1's test is rewritten to go through the real configuration reader so it can fail for the right reason, not rebuild the value itself.
- [ ] The plan's Task 8 is split to match tickets 09 and 10 (runbook and environment readiness, then acceptance by a fresh verifier session).
- [ ] The plan's execution handoff section points to `/implement-spec` and the gates in decision 0003 instead of asking Subagent-driven versus Native.
- [ ] A documentation check passes and no secret appears in the diff.
