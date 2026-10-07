# 08: Generate the frontend local environment file from the Mapbox key file

**What to build:** A developer gets a working frontend local environment file generated from their own Mapbox key file. The generator never overwrites an existing file and never prints the token, so it is safe to rerun. Implements plan Task 7.

**Blocked by:** 07 Close the gitignore gap for the frontend local environment file.

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] A test proves the generator refuses to overwrite an existing file.
- [ ] A test proves the token is never written to standard output or error.
- [ ] The generated file is ignored by git (relies on ticket 07).
- [ ] The Mapbox key file itself is read only by the generator; no agent reads or prints it.
- [ ] A secret scan of the staged diff against the real key is clean (compare, never print).
- [ ] The change is committed in the worktree only.
