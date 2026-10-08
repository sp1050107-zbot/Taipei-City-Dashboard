# 12: Harden the findings from the security review

**What to build:** The four findings of the `/cso --diff` run are closed, each test-first, without changing what the native development environment does for a normal developer:

1. (medium) The Phase 1 development containers no longer have read-write access to source that Phase 2 later executes on the host, and the runbook tells the developer to review the mounted directories before the first native run after Phase 1.
2. (low) The frontend env-file generator refuses to write when the output path is a symlink, including a dangling one, and creates the file exclusively.
3. (informational) The native launcher's one-stack-at-a-time port check fails closed when the tool it relies on is missing.
4. (informational) The frontend env-file generator accepts only a public-scope Mapbox token, and the frontend image build context excludes the local env files.

**Blocked by:** 11 Fix the four CRITICAL findings from the pre-merge review (already merged). Not blocking tickets 09 and 10 unless the owner decides otherwise.

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`. This ticket comes from the gstack `/cso --diff` static run on the integration branch (run id 1791418088423-ceae44a2132de3ec; four findings, all verified against the source).

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] **Finding 1 (read-only mount):** in the Phase 1 compose definition the backend source bind mount is read-only if and only if a test proves the Go toolchain in the dev container still runs (the check is a text test of the compose definition plus a documented, owner-run smoke step; `docker compose` is NOT run by the implementer). If read-only cannot be proven safe offline, the ticket instead records that decision as UNVERIFIED and ships the runbook step only. The runbook gains a step: before the first native run after Phase 1, run `git status` and `git diff` in the backend and frontend directories and stop on unexpected changes. The frontend mount stays read-write (the dev server writes caches there) and the reason is written down.
- [ ] **Finding 2 (symlink guard):** a test creates a dangling symlink and a symlink to an existing file at the output path and proves the generator refuses both and leaves the target untouched; the generator uses an exclusive-create write (noclobber or equivalent). Existing refusals (existing regular file, missing or empty key file) and the no-token-in-output property still pass.
- [ ] **Finding 3 (fail closed):** a test with a stub environment where the port-check tool is missing proves the launcher exits non-zero with a clear message instead of starting; the existing test hook and the 8088-in-use refusal still pass.
- [ ] **Finding 4 (token scope and build context):** the generator rejects a key file whose content does not start with the public Mapbox prefix (test uses obviously fake values for both cases, never the real key) and never prints the value; a frontend `.dockerignore` excludes the local env files and `node_modules`, with a test that checks those entries exist and that no existing build input is excluded by mistake (compare against the Dockerfile's COPY lines).
- [ ] All previously existing offline tests still pass: compose test, vite server-config test, env-local-ignored test, make-dev-env test, setup-native-model test, dev-native test, and `go test -vet=off ./global/...` with `GOTOOLCHAIN=local GOFLAGS=-mod=readonly GOPROXY=off`.
- [ ] Out-of-scope follow-ups are recorded in the Answer, not fixed here: Qdrant 6333/6334, `postgres-manager` 5432 and pgAdmin 8889 are published on all interfaces; `vector-db-upgrade` falls back to a default Qdrant API key; Redis in the container network has no password and protected mode off.
- [ ] Nothing is pushed; each finding is its own commit with a conventional-commit subject of at most 72 characters. UNVERIFIED stays explicit for anything that needs the real stack.
