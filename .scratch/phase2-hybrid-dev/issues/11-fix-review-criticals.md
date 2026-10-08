# 11: Fix the four CRITICAL findings from the pre-merge review

**What to build:** The native development environment is safe to expose on a developer laptop and actually works end to end once the owner follows the runbook. Four defects found by the pre-merge review are fixed, each test-first:

1. Redis and `postgres-data` published only on loopback. Today they are published on all interfaces, and the Redis container has no password and has protected mode off, so anyone on the same network can run commands against it.
2. The native launcher uses native locations for the ONNX Runtime library and the embedding model. Today it loads the Docker environment file first, whose template sets the model location to the container path, and then keeps that value, so the launcher reports the model as missing.
3. The native launcher reads the Docker environment file as plain data, never as shell code. Today it uses the shell's own `source`, so a value containing `$`, a backtick, `;` or quotes is expanded or executed.
4. The frontend dev server configuration really honours the local environment file and fails loudly on a port clash. Today it reads only the process environment, so `VITE_LOCAL_BE_URL` placed in the generated local environment file has no effect, the server silently moves to another port when 8080 is taken, and in native mode it listens on all interfaces.

**Blocked by:** None (can start immediately). Ticket 09 is blocked by this ticket.

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md`. This ticket comes from the gstack `/review` of the integration branch (four CRITICAL findings, all verified against the source by the orchestrator).

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [ ] **Ports (finding 1):** the compose definition publishes `redis` as `127.0.0.1:6379:6379` and `postgres-data` as `127.0.0.1:5433:5432`; `postgres-manager` stays as it is (a Phase 1 decision, out of scope here). The existing compose test is updated first, fails against the old definition, then passes. Decision 0002 item 3 is updated to say the two ports are loopback-only. `docker compose` is not run.
- [ ] **Model/library precedence (finding 2):** a test fixture environment file that defines `LM_MODEL_PATH=/opt/lm_model/onnx-e5/` (the template's value) makes the launcher fail before the fix; after the fix the launcher ignores that value and uses the native default, while a value exported by the caller before starting the launcher is still honoured. The same holds for `ORT_LIBRARY_PATH`.
- [ ] **No shell execution of the env file (finding 3):** the launcher parses `KEY=VALUE` lines literally (ignoring blank lines and comments, validating the key name, stripping one pair of matching surrounding quotes), exporting the value without expansion. A test fixture containing values with `$`, `$(...)`, a backtick, `;`, spaces and quotes proves the value arrives unchanged and that a marker file the command substitution would create is never created. Secret values still never appear in output.
- [ ] **Vite env loading (finding 4):** the dev server configuration merges the Vite-loaded local environment files (mode-aware, `VITE_` prefix and the override variable) with the process environment through an injectable loader, so a unit test with a fake loader proves `VITE_LOCAL_BE_URL` from the local environment file takes effect, and the process environment wins over the file. Native mode sets `strictPort: true` and listens on `127.0.0.1`; container mode keeps host `0.0.0.0`, port 80 and its proxy unchanged.
- [ ] The launcher also refuses to start, with a pointer to decision 0002, when something already listens on its backend port 8088 (a test uses a stub listener check, no real sockets required beyond a loopback check the test controls).
- [ ] All previously existing offline tests still pass: compose test, vite server-config test, env-local-ignored test, make-dev-env test, setup-native-model test, dev-native test, and `go test -vet=off ./global/...` with `GOTOOLCHAIN=local GOFLAGS=-mod=readonly GOPROXY=off`.
- [ ] Nothing is pushed; each fix group is its own commit with a conventional-commit subject of at most 72 characters.
- [ ] UNVERIFIED stays explicit for anything that needs the real stack (the real Docker environment file contents, the real Redis reachability from the native backend, the real Vite startup); these are checked in tickets 09 and 10. Record in the Answer that the `REDIS_PASSWORD` value in the real Docker environment file must be confirmed empty or matching the Redis container in ticket 10.
