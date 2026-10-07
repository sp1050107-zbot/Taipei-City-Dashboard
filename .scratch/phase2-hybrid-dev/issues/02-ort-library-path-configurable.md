# 02: Make the ONNX Runtime library location configurable

**What to build:** The backend can find a macOS ONNX Runtime library: the library location is read from `ORT_LIBRARY_PATH`, and the default stays the current Linux container location so the container build behaves exactly as before. Startup still requires ONNX Runtime and the embedding model and still exits if either is missing. Implements plan Task 1 as revised by ticket 01.

**Blocked by:** 01 Revise the Phase 2 plan to match the spec.

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] A test that exercises the real configuration reader fails before the change and passes after it.
- [ ] With `ORT_LIBRARY_PATH` unset the resolved location equals the current default.
- [ ] With `ORT_LIBRARY_PATH` set the model-loading code uses that value, not a literal.
- [ ] No other startup behaviour changes (database, Redis, model and tokenizer requirements are untouched).
- [ ] Backend tests that already existed still pass; the change is committed in the worktree only.
