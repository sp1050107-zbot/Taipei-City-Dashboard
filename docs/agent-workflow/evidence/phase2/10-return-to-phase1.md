# Ticket 10: return to Phase 1 (executed 2026-10-09)

Owner approved the step in chat. Runbook section 3. Every number below is from this run.

| Step | Command / action | Result |
|---|---|---|
| 0 | Identified the native processes by working directory (`lsof -a -p PID -d cwd`) | FE: `npm run dev` 6530 and `vite` 6550 in `Taipei-City-Dashboard-FE`; BE: `go run main.go` 10630 and its binary 10645 in `Taipei-City-Dashboard-BE`. Unrelated `vite` processes (Understand-Anything) were not touched. |
| 1 | `kill -INT` on the two parents, then `kill -TERM` on the BE pair that stayed alive | all four gone; no listener on 8080 or 8088 |
| 2 | `cd docker && docker compose -f docker-compose-init.yaml up dashboard-fe-init` | `added 402 packages, and audited 403 packages in 17s`, `exited with code 0`. Only that service ran (no `depends_on`), so the database init containers did not rerun (rule 9). Compose warned about orphan containers: harmless, the init file does not know the other services. |
| 2b | `ls node_modules/@rollup` | `rollup-linux-arm64-gnu`, `rollup-linux-arm64-musl`; no `rollup-darwin-arm64` (macOS modules were replaced) |
| 3 | `docker start dashboard-be dashboard-fe` | BE readiness `GET /api/v1/dashboard/` -> 200 about 20 s after start; FE `GET /` -> 200 |
| 4 | Browser, `practical_transportation_newtpe`: 3 cards, 0 requests with status >= 400, external origin only `fonts.googleapis.com` (GA stays disabled) | PASS |
| 5 | `GET /api/dev/component/60/chart?city=taipei` | 15243 rentable / 31482 free: live Airflow data survived the switch |
| 6 | `docker logs dashboard-be --since 3m` count of `fatal`/`panic` | 0 |

Not covered: admin login and debugger breakpoints (owner steps, still open); the `/geo_server/` question.
Cost of switching back to Phase 2: `npm ci` on the host again.
