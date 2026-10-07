# Taipei-City-Dashboard 本地部署 × 三層 Agent 分工 設計 Spec

日期：2026-10-06　狀態：已核准（使用者 2026-10-06 指示開始寫實作計畫）
目標 repo：`sp1050107-zbot/Taipei-City-Dashboard`（fork，upstream `taipei-doit/Taipei-City-Dashboard`，預設分支 `develop`）
本機路徑：`~/Taipei-City-Dashboard`（整合 checkout）

## 1. 目標與範圍

**目標**：在本機跑起完整儀表板（A 學習研究），並建立可長期客製開發的環境（B）；同時把「拆解別人專案、用本地 AI agent 重製」這件事本身當成練習，驗證 gstack / GSD / superpowers 三層分工。

**範圍內**
- Phase 1：官方 Docker 全容器部署，驗證整套可運作。
- Phase 2：轉混合式（DB/Redis 在 Docker，FE `npm run dev`、BE `go run` 在本機）。
- 建立 Kandev workspace、workflow、task，所有工作以 task 追蹤。
- 在 repo 補 `CLAUDE.md`、`AGENTS.md`、`MEMORY.md` 與交接機制。

**範圍外（本輪）**
- 對外服務、HTTPS、正式部署（C）。
- AI 功能（Qdrant 向量搜尋、TWCC/OpenAI/Gemini 金鑰）。Qdrant 容器可啟動但不設 LLM 金鑰。
- Codex、其他模型（先只用 Claude Code session）。
- 推送到 fork 或對 upstream 發 PR（使用者另行指示才做）。

**成功標準**
1. Phase 1：`http://localhost:8080`（FE）可開啟並顯示示範資料儀表板；BE（`:8088`）回應正常；兩個 DB 已 migrate 且載入示範資料；管理後台可用預設帳號登入。
2. Phase 2：改一行 FE 與一行 BE 程式，在本機於秒級看到結果，且可用 IDE/debugger 中斷。
3. 任何程式碼變更都經 worktree 開發與測試，最後才整合進 `~/Taipei-City-Dashboard`。
4. 新開一個 Claude session，只讀 `CLAUDE.md` + 當前 task，就能接續工作，不需重讀整個專案。

## 2. 三層分工

核心問題不是「用哪個框架」，而是「我缺的是決策、背景，還是執行步驟」。

| 層 | 工具 | 負責 | 不負責 |
|---|---|---|---|
| 決策 | gstack | 該不該做、做哪個範圍、架構取捨、設計/安全/QA 的判斷、合併前把關 | 長期狀態保存、逐步寫碼 |
| 背景 | GSD | 專案狀態、路線圖、phase 邊界、程式碼地圖、跨 session 記憶與交接 | 做商業/架構決策、TDD 細節 |
| 執行 | superpowers | 需求澄清 → 計畫 → TDD → 驗收的閉環；worktree、除錯、完成前驗證 | 決定要不要做這件事 |

**判斷規則**：需求不清 → 先 gstack；工作分歧或 session 會滿 → 加 GSD 保存背景；要穩定閉環地寫碼 → superpowers。

### 2.1 技能與 agent 對照

| 階段 | gstack（決策） | GSD（背景） | superpowers（執行） |
|---|---|---|---|
| 理解 | `/office-hours` | `gsd-onboard`、`gsd-map-codebase`（`gsd-codebase-mapper`） | `brainstorming`（僅限單一小改動） |
| 規劃 | `/plan-eng-review`、`/plan-ceo-review`（範圍）、`/plan-design-review`（FE） | `gsd-new-project`、`gsd-discuss-phase`、`gsd-plan-phase`（`gsd-planner` + `gsd-plan-checker`） | `writing-plans`（phase 內的 task 級計畫） |
| 實作 | — | `gsd-execute-phase`（僅作狀態記錄） | `using-git-worktrees`、`test-driven-development`、`subagent-driven-development` |
| 驗證 | `/qa`、`/review`、`/cso`、`/design-review` | `gsd-verify-work`、`gsd-code-review`、`gsd-secure-phase` | `verification-before-completion`、`systematic-debugging` |
| 收尾 | `/document-release`、`/health` | `gsd-extract-learnings`、`gsd-pause-work` / `gsd-resume-work` | `finishing-a-development-branch`、`requesting-code-review` |

### 2.2 重疊處的裁決（避免兩套流程互搶）

- **計畫**：GSD 擁有 phase/roadmap 層級（做什麼、什麼時候）；superpowers `writing-plans` 只在 phase 內產 task 級計畫。同一件事不得兩邊各寫一份。
- **brainstorming / review**：決策型用 gstack；superpowers 的 `brainstorming` 只用在 bounded 小改動。
- **收尾**：本機整合，不用 `/ship`（它會開 PR 推遠端）；改用 `finishing-a-development-branch` 的本機 merge 選項。`/ship` 保留給日後明確要推 fork 時。

## 3. Kandev 結構（`http://127.0.0.1:38429/`，v0.96.0）

**Workspace**：新建 `taipei-city-dashboard`，task prefix `TCD`。既有 `kandev-assistant` 不動。
**Repository**：登錄 `~/Taipei-City-Dashboard`，provider github `sp1050107-zbot/Taipei-City-Dashboard`，預設分支 `develop`，worktree 分支前綴 `feature/`。
**Agent**：`claude-acp` 的 Default profile（subscription）。不啟用 `codex-acp`。
**Executor**：程式碼變更類 task 用 `exec-worktree`；純文件/調查類 task 用 `exec-local`。

**Workflow（兩條 Kanban，欄位相同）**
- `A 部署與研究`：Phase 1 的 task。
- `B 客製開發`：Phase 2 之後的 task。

欄位：`Backlog` → `Decide (gstack)` → `Context (GSD)` → `Build (superpowers, worktree)` → `Verify` → `Merge-ready` → `Done`。
每個 task 一個 Claude session，一個 session 只做一個欄位的工作；欄位間用交接檔傳遞（見 §5）。

## 4. 分支與 worktree 紀律

- `~/Taipei-City-Dashboard` 是**整合 checkout**，停在 `develop`。
- 例外：只有文件類檔案（`CLAUDE.md`、`AGENTS.md`、`MEMORY.md`、`docs/`、`.planning/`）可直接在整合 checkout commit。
- 所有程式碼、設定、compose 變更：Kandev 建 worktree（`feature/TCD-<n>-<slug>`）→ 在其中 TDD 與測試 → 通過 `/review` → 本機 merge 回 `develop`。
- **worktree 只看得到已 commit 的內容。** 因此每次派 task 前，交接檔必須已 commit 到 `develop`，或把內容直接寫進 task description。
- 不 push、不對 upstream 發 PR，除非使用者明確指示。
- 加 upstream remote：`taipei-doit/Taipei-City-Dashboard`；`origin` 為使用者 fork。

## 5. Context 與交接機制

**檔案分工**
- `CLAUDE.md`（≤100 行，Claude 每 session 自動載入）：專案是什麼、啟動/測試指令、埠號、禁區、角色路由表、「先讀什麼」。用 `@AGENTS.md` 匯入共用部分。
- `AGENTS.md`：跨 agent 共用規則（目錄結構、慣例、worktree 紀律、不可做的事）。使用者原寫 `AGENT.md`；已確認採 `AGENTS.md`（見 §9）。
- `MEMORY.md`：專案長期記憶索引——已定案的決策、踩過的坑、目前狀態一行摘要，每條指向細節檔。只放索引，不放長文。
- `docs/decisions/`：gstack 層產出的決策記錄（一事一檔）。
- `.planning/`：GSD 狀態（PROJECT / ROADMAP / STATE / phase 計畫與地圖）。
- `docs/superpowers/specs|plans/`：superpowers 層的 task 級 spec 與計畫。

**交接協議（解決重複閱讀）**
1. 每層結束時寫**一份**交接檔，固定標頭：`目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`。
2. 下一層的 session **只讀**這份交接檔 + `CLAUDE.md`，不回頭讀上游全部文件；需要細節時按交接檔裡的路徑精準讀取。
3. 每個 Kandev task 的 description 必須包含：交接檔路徑、本 task 的唯一目標、完成條件、使用的 skill。
4. session 快滿時：執行 `gsd-pause-work`（寫 handoff）→ 更新 `MEMORY.md` → 新 session 用 `gsd-resume-work` 接續。
5. 每個 phase 結束執行 `gsd-extract-learnings`，把坑與決策濃縮進 `MEMORY.md`。

## 6. Phase 1：官方 Docker 全容器部署（A）

來源：repo `docker/` 底下 `docker-compose-db.yaml`（redis、兩個 PostGIS 16、pgAdmin、Qdrant）、`docker-compose-init.yaml`（`npm ci`、`migrateDB`、`initDashboard`）、`docker-compose.yaml`（nginx、FE、BE、vector-db-upgrade）、`.env.template`。

**Task 序列（皆在 workflow `A 部署與研究`）**
1. **TCD-1 Clone 與接線**（local）：`gh repo clone sp1050107-zbot/Taipei-City-Dashboard ~/Taipei-City-Dashboard`，加 upstream；確認 `docker/.env` 被 `.gitignore` 忽略。
2. **TCD-2 程式碼地圖**（GSD，local）：`gsd-onboard` / `gsd-map-codebase`，產出 `.planning/codebase/`。這是學習（A）的核心產出，且是後續所有 session 的共用背景。
3. **TCD-3 決策**（gstack，local）：`/plan-eng-review` 審 Phase 1 部署計畫（埠衝突、AI 功能排除、BE image 風險），寫 `docs/decisions/0001-*.md`。
4. **TCD-4 環境準備**（worktree）：檢查 80/443/8080/8088/5432/6333/8889 埠；`docker network create --driver=bridge --subnet=192.168.128.0/24 --gateway=192.168.128.1 br_dashboard`；由 `.env.template` 產生 `docker/.env`，本機專用密碼自行產生，**不寫進對話與 commit**。**更正（決策記錄 ruling 9）**：`preflight.sh` 取消，改為一行 `lsof` 迴圈只檢查 Phase 1 實際要用的 8080/8088/5432/6333/6334（不含 80/443/8889，因 nginx/pgAdmin 不啟動）。
5. **TCD-5 起基礎設施與初始化**（worktree）：`docker compose -f docker-compose-db.yaml up -d` → `docker-compose-init.yaml`（npm ci、migrateDB、initDashboard）。**更正**：只起 `redis postgres-data postgres-manager qdrant`（ruling 4/5），不含 pgAdmin。
6. **TCD-6 起應用**：`docker-compose.yaml up`（FE、BE、nginx）。Qdrant 一併啟動但不設 LLM 金鑰。**更正（ruling 3）**：Phase 1 不啟動 nginx；FE 由 Vite 直接在主機 8080 提供。
7. **TCD-7 驗證**（gstack `/qa` + superpowers `verification-before-completion`）：依 §1 成功標準逐項取證（curl、DB 查表、瀏覽器截圖）。
8. **TCD-8 補文件與記憶**：寫 `CLAUDE.md`、`AGENTS.md`、`MEMORY.md`，commit 到 `develop`；`gsd-extract-learnings`。

**已知風險與備案**
- BE 的 `dashboard-be-dev` image 含 onnxruntime 與語言模型，build 可能很大/很慢。**更正（2026-10-06 讀碼）**：BE 啟動時無條件載入該模型（`app/app.go:47`，失敗即 `log.Fatalf`），所以**沒有**「純 golang image」備案；失敗時重試或提供 HF token，見 `docs/decisions/0001-phase1-deploy-approach.md`。
- BE 啟動可能依賴 Qdrant/AI 設定；備案：Qdrant 保持啟動，AI 相關 env 留佔位值。
- 地圖需要 Mapbox token；使用者已提供（見 §9.1）。3D 建物與行政區圖層因取不到資料屬已知差異。
- `docker-compose.yaml` 使用 `external: true` 網路，網路必須先建。
- 磁碟：repo 約 1.1 GB，剩餘空間 189 GB，足夠。

## 7. Phase 2：轉混合式（B）

- Docker 只留 postgres-data、postgres-manager、redis（必要時 qdrant）；FE 用 `npm run dev`，BE 用 `go run main.go`（或 air 之類熱重載）直接跑在本機。
- 改 env 的 host 為 `localhost`，並確認各 DB 埠有對外映射（目前只有 manager 的 5432 映射，postgres-data 需補）。
- 風險：BE 的 onnxruntime 在 Apple Silicon 原生執行；若失敗，AI 功能維持停用，其餘路徑可跑。
- 這些變更屬 compose/設定變更，走 worktree 流程。
- 驗收：§1 成功標準第 2 條。
- 選配客製 task：TCD-B1「地圖改用 MapLibre + OpenFreeMap」（見 §9.1 方案 β，由使用者決定是否做）。
- 之後的客製需求（B）各自開 task，走 `Decide → Context → Build → Verify → Merge-ready`。

## 8. 完成與整合流程（每個會改碼的 task）

1. Build 欄：worktree 中先寫失敗測試 → 實作 → 通過（TDD）。
2. Verify 欄：`verification-before-completion` 取證；gstack `/review` 審 diff；FE 變更加 `/design-review` 或 `/qa`；涉及認證/輸入處理加 `/cso`。
3. Merge-ready 欄：使用者確認後，用 `finishing-a-development-branch` 本機 merge 回 `~/Taipei-City-Dashboard` 的 `develop`。
4. 回寫 `MEMORY.md`，task 移到 Done。

## 9. 已確認的決定（使用者 2026-10-06 回覆）

1. **Kandev 寫入介面已查證**（讀 `~/Documents/sp1050107-zbot/kandev` 原始碼，端點與實機 GET 皆符合）：`POST /api/v1/workspaces`、`POST /api/v1/workflows`、`POST /api/v1/workflow/steps`、`POST /api/v1/tasks`；每個 workflow step 有 `prompt` 模板（含 `{{task_prompt}}`），可把各欄位的技能指令寫進欄位。請求欄位格式在計畫的第一個 task 以讀 handler 原始碼確認，不靠猜測。
2. 檔名採 **`AGENTS.md`**。
3. **`.planning/` 納入 git**。
4. 本輪**不接 Codex**，也不碰 AI/LLM 金鑰。
5. 使用者已申請 Mapbox，token 放在 `~/Taipei-City-Dashboard/mapbox-key.txt`（已列入 `.git/info/exclude`，不會被 commit）→ 見 §9.1。

### 9.1 地圖替代方案（無 token）

**現況（已讀原始碼）**：FE 使用 `mapbox-gl ^3.1.0`；底圖樣式 `mapStyle.js` 的 source 是 `mapbox://mapbox.mapbox-streets-v8`，sprite 與 glyphs 也是 `mapbox://...`，這些都必須有 Mapbox token 才取得得到。另有 `VITE_MAPBOXTILE`（台北 3D 建物圖層）也是 Mapbox 帳號下的 tileset。行政區邊界來自自家 `/geo_server/...`（示範環境沒有）。

| 方案 | 做法 | 優點 | 缺點 |
|---|---|---|---|
| α 申請 Mapbox 免費帳號 | 每月 5 萬次 map load 免費；不放信用卡也可註冊但屬試用額度（有限制），放卡才有完整免費額度 | 零改碼，與原專案一致 | 要註冊；金鑰由你自己申請與保管；3D 建物 tileset 仍無（那是台北市府的 tileset） |
| β 換成 MapLibre GL + OpenFreeMap | 把 `mapbox-gl` 換成 `maplibre-gl`（API 高度相容的開源 fork），底圖樣式用 `https://tiles.openfreemap.org/styles/...`，不需 key、無註冊 | 完全免費且不需任何帳號；本身是很好的 B 練習（拆解 + 重製） | 要改 FE（`mapStore.js`、`mapStyle.js`、deck.gl 的 `@deck.gl/mapbox` overlay 相容性要驗證）；服務為 as-is，可用性無保證；示範用不影響 |
| γ 暫不做地圖 | 其餘功能照常驗收 | 最快 | 看不到地圖，儀表板大半價值缺席 |

**更新（使用者已有 Mapbox token）**：Phase 1 採 **α**，token 由 `mapbox-key.txt` 讀入 `docker/.env` 的 `VITE_MAPBOXTOKEN`（`docker/.env` 已被 `.gitignore` 忽略）。讀取與寫入過程不得把 token 值印到對話、log 或 commit。
- 台北 3D 建物圖層 `VITE_MAPBOXTILE` 是市府帳號下的 tileset，使用者無法取得，該圖層留空（不影響其他圖層）；行政區邊界走 `/geo_server/...`，示範環境沒有，屬預期缺項，驗收時記錄為已知差異，不算失敗。
- 方案 β（MapLibre + OpenFreeMap）降為 Phase 2 的**選配**客製練習，不再是必做；是否做由使用者在 Phase 1 完成後決定。
- 原「無 token 是否讓頁面壞掉」的疑慮不再適用。

## 10. 不做的事（YAGNI）

不接 Codex、不做 C 類正式部署、不碰 AI/LLM 金鑰、不改 upstream、不為了「完整」把 gstack 23 個角色全用上——只在上表對應的階段呼叫。
