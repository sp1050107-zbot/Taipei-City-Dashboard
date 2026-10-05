# 0001 Phase 1 部署做法

日期：2026-10-06　審查：gstack `/plan-eng-review`（計畫 `docs/superpowers/plans/2026-10-06-phase1-local-deploy.md`，commit `aeb76b3`）
審查模式：非互動。依 executing-plans 的規則，所有決策點採「建議選項」並記為 ruling，**未經使用者逐題回答**；使用者可在 Merge-ready 前推翻（見「未決定」）。

## 目標
以官方 Docker compose 在本機跑起臺北城市儀表板（FE + BE + 兩個 PostGIS + Redis + Qdrant），取得可驗收證據，作為學習（A）與之後客製開發（B）的基線。審查要回答：這份計畫的做法夠不夠簡單、會不會在中途靜默壞掉。

## 已決定
以下為本次審查的 ruling（皆為「採建議選項」，成本見括號）。

1. **BE 的嵌入模型是必經，沒有備案。** `Dockerfile` 的 `model_export` 階段必須成功。取消 spec 與計畫中「退回純 golang image」的說法。首次建置失敗時：先重試（已完成的層有快取）；若是 Hugging Face 速率限制，用 `--build-arg HF_TOKEN=<使用者自己的 token>`（Dockerfile:3 已有此 ARG，模型為公開模型，無 token 通常也可）。（成本：首次 build 時間未知，預估 10–30 分鐘，**屬未驗證估計**。）
2. **先單獨 build 再啟動**：`docker compose -f docker-compose.yaml build dashboard-be`，成功後才 `up -d`。（成本：多一個指令；好處：build 失敗不會留下半啟動的堆疊。）
3. **Phase 1 不啟動 nginx。** FE 由 Vite 直接在主機 8080 提供；nginx 的 `server_name` 是 `citydashboard.taipei`，本機用不到，且會占 80/443 並建立 `docker/nginx/ssl`。（成本：nginx 反向代理路徑不在本輪學習範圍。）
4. **Phase 1 不啟動 pgAdmin 與 `vector-db-upgrade`。** 用 `docker exec ... psql` 查資料即可；`vector-db-upgrade` 屬 AI 向量功能的一次性工作，不是 FE/BE 運作必需。Docker Desktop 只配 8.3 GB 記憶體（`docker info`），少跑一個容器有實際價值。（成本：無 GUI 看資料庫。）
5. **只啟動這些服務**：基礎設施 `redis postgres-data postgres-manager qdrant`；應用 `dashboard-fe dashboard-be`。
6. **BE 就緒判斷**：路由是 `GET("/", ...)` 掛在 `/dashboard` 群組（`app/routes/router.go:137-138`），所以探測要用帶結尾斜線的 `/api/v1/dashboard/`；不帶斜線會得到 301。同時看 `docker logs dashboard-be` 是否出現 Gin 的 `Listening and serving HTTP`。
7. **初始化是一次性動作，不重跑。** 見下方 A8、A9：init 容器的 `Exited (0)` 不代表成功；驗收以資料列數為準。要重做就刪 volume：`docker volume rm postgres_data postgres_manager_data` 再重新 init。
8. **compose 只在整合 checkout 執行。** compose 檔用固定 `container_name`（例如 `dashboard-be`），同一台機器只能有一組；Kandev worktree task 不得執行 compose。
9. **結構（Scope Challenge）**：功能清單不砍；選「Smaller arrangement」——取消 `preflight.sh` 與 `test-preflight.sh`（計畫 Task 6 的腳本），改為 Task 6 內的一行 `lsof` 迴圈檢查 `8080 8088 5432 6333 6334`。Docker 自己遇到埠衝突也會報 `port is already allocated`。計畫檔案數 12 → 10。
10. **`make-env.sh` 加強**：模板缺少預期鍵時必須失敗並列出缺的鍵（見 Q1）；測試新增一項針對真實 `docker/.env.template`。
11. **埠號綁定接受風險（Phase 1）**：compose 發佈的埠綁在 `0.0.0.0`（例如 `"5432:5432"`、`"8088:${PORT:-8080}"`），區網可連。以隨機密碼 + Qdrant API key 緩解；Phase 2 再加 loopback 綁定。
12. **Phase 2 預告**：init 容器在綁定掛載上用 Alpine 的 `npm ci`，會把 musl 版原生二進位寫進主機的 `Taipei-City-Dashboard-FE/node_modules`；Phase 2 在主機直接跑 `npm run dev` 前必須刪除該目錄並在主機重裝。

## 未決定
- **以上 ruling 1–12 尚待使用者確認**（非互動審查的結果）。若不同意，回到 Merge-ready 前改計畫即可，目前沒有任何不可逆動作。
- BE 首次 build 的實際耗時與是否被 Hugging Face 限速（Task 8 實測）。
- Docker Desktop 8.3 GB 記憶體是否足夠同時 build + 運行（Task 8 實測；不夠時調高 Docker Desktop 記憶體，屬使用者操作）。
- `GET /api/v1/dashboard/` 有 `LimitAPIRequests` 限流（`router.go:135`）；輪詢間隔 5 秒是否觸發限流，Task 8 實測。
- 外部審查（Outside Voice）未執行：使用者本輪不接 Codex；原生 Plan subagent 需要的 TaskOutput 工具在本 session 不可用。

## 下一步
依這份記錄修訂計畫並執行：Task 5（`make-env.sh` + 缺鍵檢查，worktree）→ Task 6（`lsof` 迴圈、網路、基礎設施）→ Task 7（初始化，驗收看資料列數）→ Task 8（先 build 再 up）→ Task 9 → Task 10。

## 關鍵檔案路徑
- `docker/docker-compose.yaml`、`docker/docker-compose-db.yaml`、`docker/docker-compose-init.yaml`、`docker/.env.template`
- `Taipei-City-Dashboard-BE/Dockerfile`（`model_export` 第 2 行起、`dev` 階段第 89 行起）
- `Taipei-City-Dashboard-BE/app/app.go:47-48`、`app/models/qdrant.go:102,130,142`
- `Taipei-City-Dashboard-BE/app/initial/initial.go:132-175`、`app/models/database.go:121-135`
- `Taipei-City-Dashboard-BE/app/routes/router.go:134-147`

---

# 審查本文（gstack plan-eng-review）

## Scope Challenge
- 計畫範圍：新增檔案 12 個（`kandev_bootstrap.py`、`test_kandev_bootstrap.py`、`CLAUDE.md`、`AGENTS.md`、`MEMORY.md`、`check-docs.sh`、`make-env.sh`、`test-make-env.sh`、`preflight.sh`、`test-preflight.sh`、本決策檔、證據檔）；新 class/service：0。已達 8 個檔案的複雜度門檻。
- 既有解法：Docker 對埠衝突本來就會失敗（`port is already allocated`），`preflight.sh` 只是更早、更清楚地報錯；官方 compose 檔已涵蓋全部服務。
- 結果：`scope accepted as-is`（功能清單不變），結構採 Smaller arrangement（ruling 9）。
- Search：未外查。**[Layer 1]** compose 內建行為與 `docker compose build/up <service>` 已足夠，不需新增工具。

## Section 1 — Architecture（findings 依嚴重度）
- **A1 [P2] (confidence: 9/10) `Taipei-City-Dashboard-BE/app/routes/router.go:137` — 就緒探測會誤判。** 引用：`dashboardRoutes.\n\t\t\tGET("/", controllers.GetAllDashboards)`。計畫 Task 8 Step 3 對 `/api/v1/dashboard`（無結尾斜線）等 `200`，Gin 預設會回 301，BE 明明已啟動，迴圈卻跑滿 5 分鐘。修正：用 `/api/v1/dashboard/`（ruling 6）。Disposition: accepted（ruling）。
- **A2 [P2] (confidence: 9/10) `Taipei-City-Dashboard-BE/app/app.go:47` — 嵌入模型為必經。** 引用：`global.LMSession = models.InitLmSession()`，`app/models/qdrant.go:130` 失敗即 `log.Fatalf("NewDynamicSession error: %v", err)`。修正：移除「純 golang」備案，改為 build 重試策略（ruling 1、2）。Disposition: accepted。
- **A8 [P2] (confidence: 9/10) `app/initial/initial.go:136-137, 172-178` — init 失敗會被吞掉。** 引用：`logs.FError("Error checking PostgreSQL client: %s", err)\n\t\treturn` 與 `cmd := exec.Command("psql", ..., "-f", filePath)`、`err := cmd.Run()`（輸出被丟棄；也沒有 `-v ON_ERROR_STOP=1`，psql 在 SQL 出錯時仍以 0 結束）。連 `psql` 都是執行時 `apt-get update && apt-get install -y postgresql-client`（`initial.go:159`）裝的，需要外網。後果：`Exited (0)` 不代表資料載入成功。修正：驗收看資料列數（ruling 7）。Disposition: accepted。
- **A9 [P2] (confidence: 8/10) `app/initial/initial.go:147` + `app/models/database.go:122` — 重跑不等價。** `AutoMigrate` 可重跑；示範資料用 `psql -f` 灌入，重跑可能重複寫入或靜默報錯。修正：不重跑，重置用刪 volume（ruling 7）。取代計畫 Task 7 Step 5 的「重跑觀察」。Disposition: accepted。
- **A4 [P2] (confidence: 8/10) `docker/docker-compose.yaml` — 固定 `container_name`。** 引用：`container_name: dashboard-be`。同一台機器只能有一組堆疊；Kandev worktree task 若跑 compose 會相撞。修正：ruling 8，並寫進 `AGENTS.md`。Disposition: accepted。
- **A10 [P2] (confidence: 8/10) `docker/docker-compose-init.yaml` — Phase 2 會被 `node_modules` 卡住。** 引用：`command: ["npm", "ci"]` 在綁定掛載 `../Taipei-City-Dashboard-FE` 內執行，用的是 `node:...-alpine`。`node_modules` 被 `.gitignore:19` 忽略所以不會污染 git，但主機上會留下 musl 原生二進位。修正：ruling 12，記入 MEMORY。Disposition: accepted（Phase 2 處理）。
- **A6 [P2] (confidence: 9/10) nginx 在本機沒有用途。** `docker/nginx/conf.d/default.conf` 只回應 `server_name citydashboard.taipei`，`location ^~ / { proxy_pass http://dashboard-fe/; }`；FE 已由 Vite 在 8080 提供。修正：ruling 3。`docker/nginx/ssl` 已被 `.gitignore:62` 忽略，所以原計畫 Review Focus 5 的「git 噪音」不成立，但仍不需要啟動。Disposition: accepted。
- **A7 [P3] (confidence: 8/10) `vector-db-upgrade` 非必需。** 屬 AI 向量功能一次性工作（`docker/qdrant-upgrade/upgrade_vector_db.py`）。修正：ruling 4。Disposition: accepted。
- **A5 [P3] (confidence: 7/10) 埠綁定 `0.0.0.0`。** 見 ruling 11。Disposition: accepted-as-risk。
- **A11 [P3] (confidence: 7/10) `latest` 映像。** `qdrant/qdrant:latest`、`dpage/pgadmin4:latest`、`nginx:latest`。修正：Task 8 證據檔記錄 `docker image ls --digests`。Disposition: accepted。
- **A12 [P3] (confidence: 8/10) 已知缺口。** 台北 3D 建物（`VITE_MAPBOXTILE`）與 `/geo_server` 行政區邊界取不到；驗收只要求底圖渲染，圖層錯誤屬預期。Disposition: accepted。

## Section 2 — Code quality
- **Q1 [P2] (confidence: 8/10) `docs/agent-workflow/make-env.sh`（計畫 Task 5 Step 4）— 模板改名會靜默產出缺密碼的 `.env`。** 引用：`if m and m.group(1) in values:`；不在模板內的鍵直接被略過。後果：上游把 `JWT_SECRET` 改名後，`.env` 沒有該密碼、compose 以空值啟動，毫無警告。修正：記錄實際寫入的鍵，缺任何鍵就 `sys.exit` 並列出；新增測試 7 對真實 `docker/.env.template` 執行。Disposition: accepted（ruling 10）。
- **Q2 [P3] (confidence: 7/10) `test_kandev_bootstrap.py` 會改動實機 Kandev。** `test_idempotent` 呼叫 `main()`。屬開發工具，可接受；已在 `CLAUDE.md` 標明。Disposition: accepted。
- 無跨檔共用程式碼抽取機會（兩支腳本不共享行為）。

## Section 3 — Test review
```
CODE PATHS                                              USER FLOWS
[+] docs/agent-workflow/kandev_bootstrap.py             [+] 啟動 Phase 1
  ├── ensure_workspace()  [★★★ TESTED] 建立 + 已存在       ├── [GAP→實測] BE 就緒（Task 8 Step 3）
  ├── ensure_repo()       [★★  TESTED] 登記/已存在         ├── [GAP→實測] 前端載入 + 底圖（Task 9）
  ├── ensure_steps()      [★★★ TESTED] null 與已存在       └── [GAP→實測] 管理後台登入（Task 9）
  └── ensure_tasks()      [★★  TESTED] 去重
[+] docs/agent-workflow/make-env.sh                     [+] 資料初始化
  ├── 產生 + 權限 600      [★★★ TESTED]                    ├── [GAP→實測] 資料列數 > 0（Task 7 Step 3）
  ├── 不覆寫既有檔         [★★★ TESTED]                    └── [GAP] 重跑行為（改為靜態結論，不實測）
  ├── token 缺/空          [★★★ TESTED]
  ├── 祕密不外洩           [★★★ TESTED]
  └── 模板缺鍵             [GAP] ← Q1 要補測試 7
[+] docs/agent-workflow/check-docs.sh
  └── 三件組格式/連結/祕密  [★★  TESTED]
COVERAGE: 11/15 paths tested (73%) | Code paths: 8/9 | User flows: 0/6 (以實機驗收取代，列於 Task 7–9)
QUALITY: ★★★:5 ★★:3 | GAPS: 1 code (Q1) + 6 flows（由 Task 7–9 的實測承擔）
```
需補的測試（價值卡）：
- `test-make-env.sh` 測試 7：Value: protects=模板缺任何預期鍵時 `make-env.sh` 失敗並列出該鍵; fails_when=缺鍵檢查被移除或只警告; why_new=現有測試只涵蓋已存在的鍵; seam=none。
- 其餘 flow 不寫自動化測試：它們依賴 Docker 與外網，成本高、重複價值低；以 Task 7–9 的實機取證作為驗收（每項附真實輸出）。

無 LLM prompt 變更，無 eval 範圍。

## Section 4 — Performance
- **P1 [P2] (confidence: 6/10) 記憶體：Docker Desktop 配 8.3 GB（`MemTotal=8319369216`）。** 同時有：兩個 PostGIS、Redis、Qdrant、Vite、Go 編譯（`go run`，記憶體高峰）、e5-base ONNX 載入。已移除 pgAdmin 與 `vector-db-upgrade`（ruling 4）降低壓力。實際用量未知，Task 8 以 `docker stats --no-stream` 取證。
- **P2 [P3] (confidence: 6/10) 首次 build 與 `npm ci`：** 規模未知（Hugging Face 下載 + pip；Alpine 容器經綁定掛載寫 `node_modules`，在 macOS 上可能很慢）。Task 7、8 記錄實際耗時。
- **P3 [P3] (confidence: 7/10) `dev` 階段以 `go run main.go` 啟動，每次容器重啟都會重新編譯。** Phase 1 可接受；Phase 2 熱重載時處理。
- 無 N+1、無快取議題（此計畫不新增查詢路徑）。

## NOT in scope
- nginx、pgAdmin、`vector-db-upgrade`：本機驗收不需要（ruling 3、4）。
- loopback 綁定與 compose override：Phase 2。
- 把 `latest` 映像鎖版：先記錄 digest，不改上游 compose。
- 用 Codex 做外部審查：使用者本輪不接 Codex。

## What already exists
- 官方 compose 三個檔案與 `.env.template`：直接沿用，不新增 compose 檔。
- Docker 對埠衝突的內建錯誤：取代自製 `preflight.sh`。
- `AutoMigrate`（GORM）：已冪等，不需自製 migrate 工具。

## Failure modes（每條新路徑一個真實故障）
| 路徑 | 故障 | 有測試/處理？ | 使用者看到什麼 |
|---|---|---|---|
| `model_export` build | Hugging Face 限速/斷線 | 有重試與 `HF_TOKEN` 說明 | 明確的 build 錯誤 |
| init 載入示範資料 | `apt-get` 失敗或 SQL 出錯，process 仍 exit 0 | 以資料列數驗收 | 若不驗收則**靜默失敗** → 已用 Task 7 Step 3 擋下 |
| 就緒探測 | 301 被當成未就緒 | 改探測路徑 | 逾時訊息 |
| `make-env.sh` | 模板鍵被改名 | 補測試 7 | 明確錯誤 |
| compose | 埠被占用 | Docker 內建 + `lsof` 迴圈 | 明確錯誤 |

**critical gaps：0**（init 靜默失敗已由驗收標準涵蓋）。

## Worktree parallelization strategy
Sequential implementation, no parallelization opportunity.（只有 Task 5 會改進 git 的程式碼/腳本；其餘為依序的實機操作與文件。）

## Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific finding above.

- [ ] **T1 (P2, human: ~20min / CC: ~5min)** — plan Task 8 — 就緒探測改為 `/api/v1/dashboard/` 並加 log 檢查
  - Surfaced by: Section 1 — A1 `router.go:137`
  - Files: `docs/superpowers/plans/2026-10-06-phase1-local-deploy.md`
  - Verify: Task 8 Step 3 實際回 `200`
- [ ] **T2 (P2, human: ~30min / CC: ~10min)** — plan Task 8 — 先 `build` 再 `up`，只啟動 `dashboard-fe dashboard-be`；移除 nginx、`vector-db-upgrade`、pgAdmin；移除純 golang 備案
  - Surfaced by: A2、A6、A7、P1
  - Files: 計畫檔 Task 6 Step 9、Task 8
  - Verify: `docker ps` 只含預期容器
- [ ] **T3 (P2, human: ~1h / CC: ~15min)** — plan Task 7 — 驗收改為資料列數；移除「重跑觀察」改為靜態結論與重置指令
  - Surfaced by: A8、A9
  - Files: 計畫檔 Task 7 Step 2–5、Task 9
  - Verify: 兩個 DB 的關鍵表資料列數 > 0
- [ ] **T4 (P2, human: ~30min / CC: ~10min)** — `make-env.sh` — 缺鍵即失敗 + 測試 7
  - Surfaced by: Q1
  - Files: `docs/agent-workflow/make-env.sh`、`docs/agent-workflow/test-make-env.sh`
  - Verify: `bash docs/agent-workflow/test-make-env.sh` 輸出 `PASS`（含測試 7）
- [ ] **T5 (P3, human: ~15min / CC: ~3min)** — 取消 `preflight.sh`/`test-preflight.sh`，Task 6 改一行 `lsof` 迴圈
  - Surfaced by: Scope Challenge
  - Files: 計畫檔 Task 6
  - Verify: 計畫檔不再引用 `preflight.sh`
- [ ] **T6 (P3, human: ~15min / CC: ~3min)** — `AGENTS.md` 加「compose 只在整合 checkout 執行」；`MEMORY.md` 加 Phase 2 `node_modules` 注意事項
  - Surfaced by: A4、A10
  - Files: `AGENTS.md`、`MEMORY.md`
  - Verify: `bash docs/agent-workflow/check-docs.sh` → `PASS`

## Completion summary
- Step 0: Scope Challenge — scope accepted as-is（結構採 Smaller arrangement）
- Architecture Review: 11 issues found（A1、A2、A4–A12 之中的嚴重度見上）
- Code Quality Review: 2 issues found
- Test Review: diagram produced, 1 code gap + 6 live-flow gaps（由實機驗收承擔）
- Performance Review: 3 issues found
- NOT in scope: written
- What already exists: written
- TODOS.md updates: 0 items proposed（專案沒有 TODOS.md；後續事項已寫進 Implementation Tasks 與 MEMORY.md）
- Failure modes: 0 critical gaps flagged
- Unresolved decisions: 1 in this review（ruling 1–12 尚待使用者確認）
- Outside voice: Codex skipped（使用者本輪不接 Codex）；native fallback unavailable（TaskOutput 工具不可用）；無外部覆蓋
- Parallelization: 0 lanes, 0 parallel / 1 sequential
- Lake Score: N/A（本次為非互動審查，未向使用者出題評分）

## Suppressed findings（confidence 3–4，僅供稽核校準）
- 無。

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Outside Review | none (Codex skipped by user instruction; native fallback unavailable) | Independent 2nd opinion | 0 | unavailable | no outside coverage |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | ISSUES OPEN | 17 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**OUTSIDE COVERAGE:** codex, plan-review, skipped（使用者本輪不接 Codex）；native fallback unavailable（TaskOutput 不可用）。無外部審查覆蓋，這不是 clean review。
**VERDICT:** Eng review ran in non-interactive mode; all remedies are executor rulings awaiting user confirmation — ISSUES OPEN, eng review required before treating as CLEARED.

**UNRESOLVED DECISIONS:**
- Rulings 1–12 in this record were chosen by the executor without user answers (non-interactive review); the user may overturn any of them
