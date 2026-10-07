Status: ready-for-agent

# Phase 2 混合開發環境

## Problem Statement

我是這個專案的開發者。Phase 1 讓整套系統在 Docker 裡跑起來了，但每次改前端或後端程式碼，都得在容器內重建或重啟，沒辦法用 IDE 的中斷點，也看不到改動立刻生效。同時還有幾個東西讓「直接在 macOS 主機上跑」目前行不通：

- 後端啟動時一定要載入 ONNX Runtime 與嵌入模型，缺任何一個就結束；而 ONNX Runtime 的路徑被寫死成 Linux 容器內的路徑，macOS 上無法指定。
- `postgres-data` 與 `redis` 沒有開放主機埠，主機上的後端連不到。
- 前端在非容器模式下的開發代理會指向正式站，開發者改了後端卻看不到變化，也不知道原因。
- 前端 `node_modules` 是 Alpine 容器產生的 musl 版本，在 macOS 上無法執行。
- 前端需要的 Mapbox 本機環境檔目前沒被 gitignore 涵蓋，一旦建立就有被 commit 外洩的風險。

## Solution

提供 **Phase 2**：資料庫、Redis、Qdrant 留在 Docker；前端（`npm run dev`）與後端（`go run`）以**主機原生模式**跑在 macOS 上。開發者用一組有文件的步驟就能啟動，改前端一行約 1 秒內由 Vite HMR 更新；改後端一行需手動重啟，幾秒內生效，且實測秒數會被記錄下來。同一時間只跑 Phase 1 或 Phase 2 其中一種，出問題時有一節 runbook 能一步回到 Phase 1。整個過程不重跑資料初始化，不讀取或印出任何祕密。

## User Stories

1. As a developer, I want the backend to start natively on my Mac, so that I can use my IDE debugger on it.
2. As a developer, I want the ONNX Runtime library location to be configurable by an environment variable, so that the backend can find the macOS library instead of the hard-coded Linux path.
3. As a developer, I want the default library location to stay exactly as it is today, so that the container build keeps working without any change.
4. As a developer, I want a failing test that proves the library path override works, so that nobody breaks it silently later.
5. As a developer, I want `postgres-data` published on host port 5433, so that the native backend can reach the dashboard database.
6. As a developer, I want `redis` published on host port 6379, so that the native backend can reach it.
7. As a developer, I want `postgres-manager` to keep host port 5432, so that existing access keeps working.
8. As a developer, I want a test that fails if either new port mapping is missing, so that the compose definition cannot drift.
9. As a developer, I want one launcher that exports every environment value the backend needs for host networking, so that I never type connection strings by hand.
10. As a developer, I want the launcher to take real secrets from the existing Docker environment file without printing them, so that I can run the backend without leaking credentials.
11. As a developer, I want the launcher to override only the values that differ for host networking, so that the rest stays identical to Phase 1.
12. As a developer, I want the launcher to fail with a clear message when the ONNX Runtime library or the embedding model is missing, so that I do not have to decode a fatal log line.
13. As a developer, I want a one-time setup step that obtains the macOS ONNX Runtime 1.23.2 library from the official release, so that the version matches the container image.
14. As a developer, I want that download verified by SHA256 before it is used, so that I do not run an unverified binary.
15. As a developer, I want to be told the file name, source and size and to approve before anything is downloaded, so that nothing is fetched without my consent.
16. As a developer, I want the embedding model copied out of the already-built backend image, so that I do not re-run the Python export on my Mac.
17. As a developer, I want the library and model stored in places that are already gitignored, so that large binaries never get committed.
18. As a developer, I want the frontend dev proxy to target the local backend by default in native mode, so that I never silently hit the production site.
19. As a developer, I want the proxy target to be overridable by an environment value, so that I can point it elsewhere when needed.
20. As a developer, I want a test that fails if native mode targets the production site, so that this trap cannot return.
21. As a developer, I want the frontend served on host port 8080 and the backend on 8088, so that my bookmarks from Phase 1 still work.
22. As a developer, I want the gitignore gap for the frontend local environment file closed before that file is ever created, so that the Mapbox token cannot be committed by accident.
23. As a developer, I want the local environment file generated from my own Mapbox key file, never overwriting an existing file and never printing the token, so that setup is safe to rerun.
24. As a developer, I want a documented step that reinstalls frontend dependencies on the host, so that the musl binaries from the Alpine init container are replaced.
25. As a developer, I want the frontend pinned to Node 21 and the backend to use the host Go toolchain without downloading another one, so that the environment matches what the project was built with.
26. As a developer, I want to be asked before Node 21 is installed, so that no tool is installed without my approval.
27. As a developer, I want the two Phase 1 application containers stopped during Phase 2, so that host ports 8080 and 8088 are free.
28. As a developer, I want the data and Redis containers to stay up, so that no data is reinitialised.
29. As a developer, I want to be asked before the `postgres-data` and `redis` containers are recreated, so that I control the only step that touches the databases.
30. As a developer, I want recreating those containers to keep their volumes, so that no sample data is lost and initialisation is not rerun.
31. As a developer, I want one runbook section that returns me to Phase 1 by stopping the native processes and restarting the two containers, so that I can recover quickly.
32. As a developer, I want the extra published ports to be harmless to Phase 1, so that returning does not require undoing them.
33. As a developer, I want the observed wall-clock time for a backend restart recorded, so that the "within a few seconds" claim is backed by a number.
34. As a developer, I want the observed frontend update time recorded, so that the "about 1 second" claim is backed by a number.
35. As a developer, I want evidence that a debugger breakpoint was hit on both frontend and backend, and which tool was used, so that the debugging claim is verified.
36. As a verifier, I want to run the acceptance checklist in a fresh session, so that the implementer does not grade their own work.
37. As a verifier, I want every pass or fail backed by a command and its output stored with the evidence, so that results can be re-checked.
38. As a verifier, I want anything I cannot prove marked UNVERIFIED instead of passed, so that gaps stay visible.
39. As the owner, I want to confirm the admin login myself, so that no agent ever needs the admin password.
40. As the owner, I want the work split into tickets with explicit blocking relationships, so that independent parts run in parallel and dependent parts wait.
41. As the owner, I want the work merged to `develop` only after the review gates pass, so that secrets and regressions are caught first.
42. As the owner, I want nothing pushed to any remote without my explicit say-so, so that the local-first rule holds.

## Implementation Decisions

- **Scope of change** is limited to the pieces below. Each is a separate module with its own owner ticket; the existing implementation plan breaks them into eight tasks and remains the working draft for how.
- **Backend configuration module**: gains an ONNX Runtime library path setting read from `ORT_LIBRARY_PATH`. Default stays the current Linux path. The model-loading code reads this setting instead of a literal. Startup behaviour is otherwise unchanged: the backend still requires ONNX Runtime and the embedding model and still exits if either is missing.
- **Database compose definition**: publishes `postgres-data` on host 5433 and `redis` on host 6379. `postgres-manager` is unchanged on 5432. Applying the change means recreating those two containers in the integration checkout, after the owner approves; volumes are kept and no initialisation is rerun.
- **Native backend launcher**: loads the secrets from the existing Docker environment file, then overrides only host-networking values: database hosts to localhost, dashboard database port 5433, manager port 5432, Redis host localhost port 6379, Qdrant URL to localhost:6333, listening address to localhost with `GIN_PORT=8088`, and `ORT_LIBRARY_PATH` to the macOS library. It never prints secret values. The backend does not read an environment file itself, so the launcher is the only way values reach it.
- **Runtime preparation step**: obtains `onnxruntime-osx-arm64-1.23.2` from the official release, verifies SHA256, and extracts the embedding model files (`model.onnx`, `tokenizer.json`) from the built backend dev image. Output lands in already-gitignored locations. The user approves the download first.
- **Frontend dev proxy configuration**: in native mode the `/api/dev` proxy targets the local backend (default `http://localhost:8088`, overridable by `VITE_LOCAL_BE_URL`). The container-mode behaviour is unchanged. The proxy configuration is extracted so a test can check it.
- **Frontend local environment**: the gitignore is extended to cover the local environment file before any generator exists. A generator builds that file from the owner's Mapbox key file, refuses to overwrite, and never prints the token.
- **Frontend dependencies**: reinstalled on the host with Node 21 to replace the musl binaries. Node 21 installation requires the owner's approval first. Backend uses `GOTOOLCHAIN=local` with the host Go.
- **Stack rule**: Phase 1 and Phase 2 never run at the same time (decision 0002). During Phase 2 the frontend container and backend container are stopped, the frontend serves on 8080 and the backend on 8088.
- **Execution** follows decision 0003: tickets under the Phase 2 feature folder, executed by `/implement-spec` in parallel on the frontier, merged into one integration branch, gated by verification-before-completion, `/review` and `/cso --diff` before merging to `develop`.
- **Ticket blocking edges**: Task 3 is blocked by Tasks 1 and 2; Task 7 is blocked by Task 6; Task 8 is blocked by Tasks 1 to 7; the others are independent.
- **Success criterion**: frontend change visible via Vite HMR in about 1 second; backend change live a few seconds after a manual restart; no new hot-reload tool. Measured times are recorded in the evidence.
- **Debugging**: breakpoints must be shown to work on both frontend (browser dev tools) and backend (IDE debugger); the tool used is recorded.
- **Draft handling**: the current plan lives on the unmerged P2-00 branch. After this spec is accepted that branch is merged to `develop` and one ticket revises the plan to match this spec.

## Testing Decisions

- A good test checks external behaviour only: what a request returns, what a launcher exports, what a configuration resolves to. It does not assert on how the code is organised.
- **Proposed seams** (please confirm; the ideal is one, this proposes two):
  1. **Highest seam: the running hybrid stack, probed over HTTP and by process behaviour.** The verifier checks the readiness probe on the backend dashboard route (with trailing slash), the frontend root, the map page, and the admin page being reachable, and records restart and HMR timings. This covers the whole chain with no knowledge of internals.
  2. **Lower seam: the per-task checks the plan already defines**, used only for behaviour the highest seam cannot show: the library path override, the two published ports, the proxy default not being production, the gitignore covering the local environment file, and the generator never printing or overwriting. These are small script or unit tests like the existing prior art.
- **Modules tested**: backend configuration, database compose definition, native launcher, frontend proxy configuration, gitignore coverage, local environment generator, plus the end-to-end acceptance checklist.
- **Prior art**: the existing mocked unit test for the Kandev bootstrap script, the shell tests for the env generator, and the documentation check script.
- **Acceptance checklist** (fresh verifier session, evidence under the Phase 2 evidence folder):
  1. Backend starts natively and stays up (no fatal exit on ONNX Runtime or model).
  2. Backend readiness probe returns success; databases and Redis connect.
  3. Frontend serves on 8080 and proxies to the local backend, not production.
  4. Dashboard page, map page and admin page load.
  5. Frontend HMR time and backend restart time recorded.
  6. Breakpoint hit on frontend and on backend, tool noted.
  7. Return-to-Phase-1 section works: stop native processes, restart the two containers, probe succeeds.
  8. Secret scan of all staged changes is clean; the local environment file is ignored by git.
  9. **Admin login: confirmed by the owner, not by an agent.**

## Out of Scope

- Populating Qdrant (`vector-db-upgrade`) and the AI component search (`POST /component`).
- nginx, pgAdmin, any production or cloud deployment.
- Re-initialising the databases or changing sample data.
- A hot-reload tool for the backend.
- Removing the Google Analytics tracking code or replacing Mapbox.
- Linux or Windows hosts; this targets macOS arm64 only.
- Pushing to any remote or opening a pull request.

## Further Notes

- **UNVERIFIED** (must be reported as such until proven):
  1. macOS ONNX Runtime 1.23.2 compatibility with the Go binding version the project uses.
  2. Whether the host Go (1.27.1) builds and runs this project cleanly with the local toolchain.
  3. Whether Node 21 plus the existing lock file installs cleanly on macOS arm64.
  4. That the frontend local environment file and the Mapbox token cannot leak (depends on the gitignore ticket landing first and being tested).
  5. The HTTP status `POST /component` returns when the Qdrant collection does not exist (affects only the out-of-scope feature).
- **Working draft of the how**: `docs/superpowers/plans/2026-10-07-phase2-hybrid-dev.md` on branch `feature/p2-00-phase-2-far`, commit `1813acae`. This spec references it and does not repeat its content.
- **Known gaps in the current plan** (found while cross-checking this spec on 2026-10-07; the "revise the plan to match this spec" ticket must close them):
  1. Task 4 downloads the official macOS ONNX Runtime 1.23.2 release but the plan contains **no SHA256 verification** and no prompt before the download. This spec requires both (user stories 14 and 15).
  2. Task 3's launcher uses the library location that Task 4 produces only as a default value, so there is no code dependency between them; the end-to-end dependency shows up in Task 8. Keep them parallel, but Task 8 must check that both are in place.
  3. Task 8's port wording mixes 8080 and 8088 for the backend; this spec fixes frontend 8080 and backend 8088 (decision 0002).
  4. Task 1's test builds the configuration value itself instead of exercising the real loading path; the revision should make the test go through the actual configuration reader so it can fail for the right reason.
- **Related decisions**: `docs/decisions/0001-phase1-deploy-approach.md`, `0002-phase1-phase2-one-stack-at-a-time.md`, `0003-phase2-execution-engine-and-gates.md`. Vocabulary is in `GLOSSARY.md`.
- Tracker: this is a local markdown spec. Its Kandev card, if created later, contains only this file's path.
