# 05: macOS ONNX Runtime and embedding model setup step

**What to build:** A one-time setup step that gives the developer what the backend needs to start natively: the official macOS ONNX Runtime 1.23.2 library, verified by SHA256, and the embedding model files copied out of the already-built backend dev image, both stored in already-gitignored locations. Rerunning it when the files already exist does nothing. Implements plan Task 4 as revised by ticket 01.

**Blocked by:** 01 Revise the Phase 2 plan to match the spec.

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`, `GLOSSARY.md`, `.scratch/phase2-hybrid-dev/spec.md`, `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`, `docs/decisions/0003-phase2-execution-engine-and-gates.md`, and the plan `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` (the working draft of the how; reference it by Task number, do not copy it). The plan is on `develop` once the P2-00 branch has been merged; if it is not there yet, stop and ask the owner.

**Standing rules:** code and configuration changes only in a worktree with TDD (AGENTS.md rule 1); no `git push` and no pull request (rule 3); never read, print or commit secrets such as the Mapbox key file or the Docker environment file (rule 4); `docker compose` only in the integration checkout and never from a worktree (rule 7); anything unproven is reported as UNVERIFIED, never as passed.

## Acceptance criteria

- [x] Before downloading anything the step tells the owner the file name, source and size and waits for explicit approval; a test proves it does not download without approval.
- [x] The download comes from the official release for the pinned version only, and the SHA256 is verified before the library is used; a corrupted archive is rejected.
- [x] The embedding model files (`model.onnx` and `tokenizer.json`) are obtained from the built dev image, not by re-running the Python export on the Mac.
- [x] When the library and model already exist the step performs no download and no image access (idempotent).
- [x] Both outputs land in locations the backend's gitignore already covers; a check proves `git status` shows nothing new.
- [ ] Compatibility between ONNX Runtime 1.23.2 and the project's Go binding is recorded as UNVERIFIED until the backend actually loads the model in ticket 10.
- [x] The change is committed in the worktree only.

## Answer

Implemented in `Taipei-City-Dashboard-BE/` (commit `4f5b700c`): `setup-native-model.sh`, `test-setup-native-model.sh`, `onnxruntime.sha256`.

- Approval gate: without `ORT_DOWNLOAD_APPROVED=yes` the script prints file name and source URL, makes no network call, exits 2 (test case 2).
- SHA256 gate: mismatch deletes the download, extracts nothing, exits 4 (case 3). Missing, empty or placeholder digest file refuses before any download (cases 5, 6).
- `onnxruntime.sha256` is committed as the placeholder `UNSET`, which the script rejects (case 7). **The real digest and the download size are UNVERIFIED**: the owner must paste the official digest from the release page at approval time. Nothing was downloaded or computed.
- Model: `model.onnx` and `tokenizer.json` are copied from the `dashboard-be-dev:latest` image via `docker create`/`cp`/`rm` (path `/opt/lm_model/onnx-e5` confirmed from the Dockerfile). Only tested with a stub docker; real image access UNVERIFIED.
- Idempotent: with library and both model files present, no curl and no docker call (case 1); library present but model missing runs docker only (case 8).
- Outputs are covered by the BE `.gitignore` (case 9); no binary is committed.
- Compatibility of ONNX Runtime 1.23.2 with the project's Go binding is UNVERIFIED until the backend loads the model (ticket 10).
- Run: `Taipei-City-Dashboard-BE/test-setup-native-model.sh`.
