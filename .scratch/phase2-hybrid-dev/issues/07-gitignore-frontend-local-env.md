# 07: Close the gitignore gap for the frontend local environment file

**What to build:** The frontend local environment file can never be committed by accident: the gitignore covers it before any generator exists. This must land before ticket 08. Implements plan Task 6.

**Blocked by:** None (can start immediately, after the P2-00 branch has been merged to `develop`).

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] A test creates a throwaway local environment file name and proves git ignores it, and fails before the gitignore change.
- [ ] The existing ignore entries for the other environment files are unchanged.
- [ ] The test never uses or prints a real token.
- [ ] The change is committed in the worktree only.
