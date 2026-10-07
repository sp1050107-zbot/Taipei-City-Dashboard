# 08: Generate the frontend local environment file from the Mapbox key file

**What to build:** A developer gets a working frontend local environment file generated from their own Mapbox key file. The generator never overwrites an existing file and never prints the token, so it is safe to rerun. Implements plan Task 7.

**Blocked by:** 07 Close the gitignore gap for the frontend local environment file.

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] A test proves the generator refuses to overwrite an existing file.
- [x] A test proves the token is never written to standard output or error.
- [x] The generated file is ignored by git (relies on ticket 07).
- [x] The Mapbox key file itself is read only by the generator; no agent reads or prints it.
- [ ] A secret scan of the staged diff against the real key is clean (compare, never print).
- [x] The change is committed in the worktree only.

## Answer

Added `Taipei-City-Dashboard-FE/make-dev-env.sh` (key file from argument, `$MAPBOX_KEY_FILE`, or the repo's `mapbox-key.txt`; output `.env.local` or `$ENV_LOCAL_OUT`; refuses to overwrite, fails on missing or empty key, mode 600, prints only "wrote <path>") and `Taipei-City-Dashboard-FE/test-make-dev-env.sh`. Scripts added with `git add -f` because upstream ignores `*.sh`.

- Overwrite refusal: tested, existing content verified unchanged. Token never on stdout or stderr: tested on both the success and refusal paths using a fake sentinel key in a temp dir. Missing and empty key files fail without creating output.
- RED: first run failed (generator not found). GREEN: `Taipei-City-Dashboard-FE/test-make-dev-env.sh` prints PASS; `test-env-local-ignored.sh` still PASS and `git check-ignore .env.local` confirms the output name is ignored (ticket 07).
- The real `mapbox-key.txt` was never read, printed or used; the generator was never run against it.
- Secret scan of the staged diff against the real key: done by orchestrator (box left unticked).
- Commit: see `git log -1` on branch `feature/phase2-08`.
