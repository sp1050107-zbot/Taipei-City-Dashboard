# Ticket 10: backend breakpoint with Delve (2026-10-10)

Dispatch: `~/control-tower/dispatch/Taipei｜實作與營運.md` item 1 (L0). Native stack (Phase 2) was running.

**What this proves:** Delve can attach to this backend (same env file, same ONNX Runtime and model, same `go run` entry point) and stop on a route handler. **It does not prove** that an IDE's Run and Debug works; that still needs the owner's IDE.

## Method

`dev-native.sh` ends with `exec go run main.go`. To keep the launcher and its environment handling unchanged, it was started with a PATH shim (scratchpad only, not in the repo) whose `go` turns `go run` into `dlv debug --headless --listen=127.0.0.1:2345 --api-version=2 --accept-multiclient .` and forwards every other `go` command (Delve's own build) to `/opt/homebrew/bin/go`.

| Step | Command / action | Result |
|---|---|---|
| 1 | Stopped the native backend: `go run main.go` (5404) and its binary (5435), both cwd `Taipei-City-Dashboard-BE` | stopped, 8088 free |
| 2 | `PATH=<shim>:$PATH bash Taipei-City-Dashboard-BE/dev-native.sh` | `API server listening at: 127.0.0.1:2345` after about 14 s (debug build) |
| 3 | `dlv connect 127.0.0.1:2345`: `break TaipeiCityDashboardBE/app/controllers.GetAllDashboards`, `continue` | `Breakpoint 1 set at 0x1038036f0 ... ./app/controllers/dashboard.go:24` |
| 4 | `curl http://127.0.0.1:8088/api/v1/dashboard/` once 8088 listened (about 4 s) | `> [Breakpoint 1] ...GetAllDashboards() ./app/controllers/dashboard.go:24 (hits goroutine(26):1 total:1)` |
| 5 | `stack 3`, `print c.Request.URL.Path` | frame 0 `GetAllDashboards` at `dashboard.go:24`, called through `gin.(*Context).Next` and `middleware.LimitTotalRequests.func1` (`rateLimit.go:85`); path `"/api/v1/dashboard/"` |
| 6 | `clearall`, `continue` | the held request completed: `200` |
| 7 | Killed the client and the headless Delve, then `bash Taipei-City-Dashboard-BE/dev-native.sh` again | native backend back: `GET /api/v1/dashboard/` 200 after about 6 s; listener is the go-build binary, no `dlv` process left; frontend proxy `/api/dev/dashboard/` 200 |

The client resumed right after printing the stop (scripted), so the curl time (0.097 s) does not measure how long it was held.

## Tool used

Delve 1.27.2 (`~/go/bin/dlv`, installed 2026-10-09 with `go install github.com/go-delve/delve/cmd/dlv@latest`), headless mode, terminal client. No IDE. No macOS developer-tools prompt appeared.

## Still open

Frontend breakpoint (owner, Chrome DevTools Sources). The acceptance line "A breakpoint is hit on the frontend and on the backend" stays unticked until then.
