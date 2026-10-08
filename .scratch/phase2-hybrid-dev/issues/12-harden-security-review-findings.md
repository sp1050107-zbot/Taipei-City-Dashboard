# 12: Harden the findings from the security review

**What to build:** The four findings of the `/cso --diff` run are closed, each test-first, without changing what the native development environment does for a normal developer:

1. (medium) The Phase 1 development containers no longer have read-write access to source that Phase 2 later executes on the host, and the runbook tells the developer to review the mounted directories before the first native run after Phase 1.
2. (low) The frontend env-file generator refuses to write when the output path is a symlink, including a dangling one, and creates the file exclusively.
3. (informational) The native launcher's one-stack-at-a-time port check fails closed when the tool it relies on is missing.
4. (informational) The frontend env-file generator accepts only a public-scope Mapbox token, and the frontend image build context excludes the local env files.

**Blocked by:** 11 Fix the four CRITICAL findings from the pre-merge review (already merged). Not blocking tickets 09 and 10 unless the owner decides otherwise.

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`. This ticket comes from the gstack `/cso --diff` static run on the integration branch (run id 1791418088423-ceae44a2132de3ec; four findings, all verified against the source).

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] **Finding 1 (read-only mount):** in the Phase 1 compose definition the backend source bind mount is read-only if and only if a test proves the Go toolchain in the dev container still runs (the check is a text test of the compose definition plus a documented, owner-run smoke step; `docker compose` is NOT run by the implementer). If read-only cannot be proven safe offline, the ticket instead records that decision as UNVERIFIED and ships the runbook step only. The runbook gains a step: before the first native run after Phase 1, run `git status` and `git diff` in the backend and frontend directories and stop on unexpected changes. The frontend mount stays read-write (the dev server writes caches there) and the reason is written down. (Resolved via the fallback branch: read-only was NOT proven offline, so the compose mount is unchanged; decision recorded UNVERIFIED in the Answer, runbook step plus owner-run smoke step shipped.)
- [x] **Finding 2 (symlink guard):** a test creates a dangling symlink and a symlink to an existing file at the output path and proves the generator refuses both and leaves the target untouched; the generator uses an exclusive-create write (noclobber or equivalent). Existing refusals (existing regular file, missing or empty key file) and the no-token-in-output property still pass.
- [x] **Finding 3 (fail closed):** a test with a stub environment where the port-check tool is missing proves the launcher exits non-zero with a clear message instead of starting; the existing test hook and the 8088-in-use refusal still pass.
- [x] **Finding 4 (token scope and build context):** the generator rejects a key file whose content does not start with the public Mapbox prefix (test uses obviously fake values for both cases, never the real key) and never prints the value; a frontend `.dockerignore` excludes the local env files and `node_modules`, with a test that checks those entries exist and that no existing build input is excluded by mistake (compare against the Dockerfile's COPY lines).
- [x] All previously existing offline tests still pass: compose test, vite server-config test, env-local-ignored test, make-dev-env test, setup-native-model test, dev-native test, and `go test -vet=off ./global/...` with `GOTOOLCHAIN=local GOFLAGS=-mod=readonly GOPROXY=off`.
- [x] Out-of-scope follow-ups are recorded in the Answer, not fixed here: Qdrant 6333/6334, `postgres-manager` 5432 and pgAdmin 8889 are published on all interfaces; `vector-db-upgrade` falls back to a default Qdrant API key; Redis in the container network has no password and protected mode off.
- [x] Nothing is pushed; each finding is its own commit with a conventional-commit subject of at most 72 characters. UNVERIFIED stays explicit for anything that needs the real stack.

## Answer

Commits (branch `feature/phase2-12`, nothing pushed):

- `a29b3358` fix(fe): refuse symlinked output and create env file exclusively (finding 2)
- `6fca697c` fix(be): fail closed when nc is missing in the native launcher (finding 3)
- `ee519dd0` fix(fe): accept only public Mapbox tokens and add a .dockerignore (finding 4)
- `1847d3b4` docs: explain mount review and add owner-run read-only smoke step (finding 1)

Evidence (RED then GREEN, mutation checks):

- Finding 2: new symlink tests (dangling and to an existing file) failed against the old script ("should refuse dangling symlink", target created), pass after `-L` guard plus `set -o noclobber`. Mutation (guard and noclobber removed) turned the test red again.
- Finding 3: new test with a PATH holding only `dirname` failed on the missing message before the fix; passes after the `command -v nc` check. Mutation (check disabled) red again. Test hook and 8088 refusal still pass.
- Finding 4: `sk.`, no-prefix and mid-string `pk.` fake values were accepted before the fix (RED), now rejected without printing the value; `.dockerignore` test failed with the file missing, passes with `.env.local`, `.env.*.local`, `node_modules`, and checks no tracked FE file (the `COPY . .` input) is excluded. Mutations (accept-all case, and a `src` pattern in `.dockerignore`) went red. The existing fake sentinel was already `pk.`-prefixed.
- Finding 1: **UNVERIFIED** whether a read-only backend bind mount keeps `go run` working in the container (no docker allowed to the implementer). The compose mount is unchanged. The runbook now says why the review of both directories is needed (containers can write there) and has an owner-run smoke step for trying `:ro` on the backend mount; the frontend mount must stay read-write because the Vite dev server writes caches. `check-docs.sh` now fails if the runbook loses the review step (checked by mutation).

Offline tests, all PASS: docker/test-docker-compose-db.py, vite.server-config.test.mjs, test-env-local-ignored.sh, test-make-dev-env.sh, test-setup-native-model.sh, test-dev-native.sh, check-docs.sh, and `go test -vet=off ./global/...` (GOTOOLCHAIN=local GOFLAGS=-mod=readonly GOPROXY=off).

Out-of-scope follow-ups (not fixed here): Qdrant 6333/6334, `postgres-manager` 5432 and pgAdmin 8889 are published on all interfaces; `vector-db-upgrade` falls back to a default Qdrant API key; Redis in the container network has no password and protected mode is off.
