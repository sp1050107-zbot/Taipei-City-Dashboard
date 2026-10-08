# AGENTS.md — Taipei-City-Dashboard（本地 fork）

本檔是所有 agent 共用的專案規則。Claude 由 `CLAUDE.md` 匯入本檔。

## 這是什麼
臺北市城市儀表板（資料視覺化平台）的本機 fork，用於「學習研究（A）」與「客製開發（B）」。
上游：`taipei-doit/Taipei-City-Dashboard`；origin：`sp1050107-zbot/Taipei-City-Dashboard`；預設與整合分支：`develop`。

## 結構
- `Taipei-City-Dashboard-FE/` Vue 3 + Vite 前端（Mapbox GL、deck.gl）
- `Taipei-City-Dashboard-BE/` Go 1.25 + Gin 後端（路由在 `app/routes/router.go`，環境變數在 `global/global.go`）
- `Taipei-City-Dashboard-DE/` 資料工程
- `docker/` compose 檔、`.env.template`、nginx
- `db-sample-data/` 示範資料（`dashboard-demo.sql`、`dashboardmanager-demo.sql`）
- `docs/superpowers/{specs,plans}/` spec 與計畫；`docs/decisions/` 決策記錄；`.planning/` GSD 狀態

## 本機埠號（Phase 1 全容器；見規則 8，nginx/pgAdmin 不啟動）
| 服務 | 主機埠 | Phase 1 狀態 |
|---|---|---|
| 前端 (Vite) | 8080 | 啟動 |
| 後端 (Gin) | 8088 | 啟動 |
| postgres-manager | 5432 | 啟動 |
| qdrant | 6333 / 6334 | 啟動 |
| nginx | 80 / 443 | 未啟動（官方 compose 可配，Phase 1 不需要） |
| pgAdmin | 8889 | 未啟動（官方 compose 可配，Phase 1 不需要） |

## 工作規則
1. 程式碼、腳本、compose、設定的變更：只在 worktree（`~/Taipei-City-Dashboard-worktrees/<name>`，分支 `feature/<slug>`）進行，TDD，通過後才本機 merge 回 `develop`。例外（使用者 2026-10-07 同意）：`/implement-spec` 可自動開多個實作子 agent worktree，並由 merger 子 agent 合併到**同一條整合分支**（`feature/<spec-slug>`）；整合分支經 `/code-review` 與驗證通過後，才用一次本機 merge 回 `develop`。子 agent worktree 完成後要清理，且不得直接 merge 到 `develop`。
2. 只有 `CLAUDE.md`、`AGENTS.md`、`MEMORY.md`、`GLOSSARY.md`、`docs/`（含 `docs/agents/`、`docs/decisions/`）、`.planning/`、`.scratch/`（本機 tracker 的 spec 與票，見「追蹤與領域文件」）、`.ua/`（Understand-Anything 的設定；大檔 `knowledge-graph.json` 與 `fingerprints.json` 可用 `/understand` 重建，已列入 `.gitignore`，不入版控，使用者 2026-10-08 決定）可直接在整合 checkout commit。`.scratch/` 內容同樣適用規則 4（不得放祕密）。
3. 不 `git push`、不對 upstream 發 PR，除非使用者明確指示。
4. 祕密：`mapbox-key.txt`、`docker/.env` 永不 commit、永不印出。commit 前用 token 的完整字串比對 staged diff（只比對，不印出）。
5. 不設定任何 LLM/AI 服務金鑰（TWCC/OpenAI/Gemini）。注意：BE 啟動時**一定會**載入本地嵌入模型（`intfloat/multilingual-e5-base` 的 ONNX 版）與 onnxruntime，缺任何一個就 `log.Fatalf` 結束；所以 Docker build 的 `model_export` 階段是必經，不能略過。
6. worktree 只看得到已 commit 的內容；交接檔先 commit 再派工。`/handoff` 預設把檔案寫到 `$TMPDIR`（worktree 與其他 harness 看不到），所以：用 `/handoff` 產生後，要把檔案複製到 `.planning/handoffs/<YYYY-MM-DD>-<topic>.md`（保持五個標頭）並 commit，再把這個**已 commit 的路徑**交給下一個 session / Kandev 任務；`$TMPDIR` 的檔案不得當作交接依據。
7. docker compose 只在整合 checkout（`~/Taipei-City-Dashboard/docker`）執行：compose 檔用固定 `container_name`，同一台機器只能有一組堆疊；worktree / Kandev task 不得跑 compose。
8. Phase 1 只啟動 `redis postgres-data postgres-manager qdrant dashboard-fe dashboard-be`；不啟動 nginx、pgAdmin、`vector-db-upgrade`（見 `docs/decisions/0001-phase1-deploy-approach.md`）。
9. 資料初始化是一次性動作，不重跑（init 會吞錯、重跑可能重複寫入）；要重做就刪 `postgres_data` / `postgres_manager_data` volume。

## 追蹤與領域文件（使用者 2026-10-07 決定）
- **票（tracker）**：Kandev 是任務看板；spec 與票的**內容**是本機 markdown：`.scratch/<feature>/spec.md`、`.scratch/<feature>/issues/<NN>-<slug>.md`（阻擋關係寫在票內 `Blocked by:`）。一張票對應一張 Kandev 卡，卡片描述只放該票檔案路徑，不複製內容，避免兩處不一致。
- **Kandev 是擁有者回查進度用的看板（強制，使用者 2026-10-08 決定）**：每張票都必須有卡，卡片所在欄位必須跟票的 `Status:` 一致。新增票、改 `Status:`、或票多了 `## Answer` 之後，**同一回合、回報完成之前**執行 `python3 docs/agent-workflow/kandev_bootstrap.py`（冪等，會補卡並移動卡片），再用 `python3 docs/agent-workflow/test_kandev_bootstrap.py` 驗證。對應：ready-for-agent→Backlog、claimed→Build (worktree)、claimed 且有 Answer→Verify（等擁有者驗收）、resolved/wontfix→Done；標題上限 60 字。
- **ADR 與決策**：只放 `docs/decisions/`，不建立 `docs/adr/`；`GLOSSARY.md` 放 repo 根目錄。同一個決定只寫在一處，其他地方用路徑引用。
- 這些位置要在 `docs/agents/*.md`（由 `/setup-matt-pocock-skills` 產生）中同樣設定，讓 matt skills 與本檔一致。

## 三層分工與交接
- gstack＝決策與把關（`/office-hours`、`/plan-eng-review`、`/review`、`/qa`、`/cso`）
- GSD＝背景與交接（`gsd-map-codebase`、`gsd-plan-phase`、`gsd-pause-work`、`gsd-resume-work`、`gsd-extract-learnings`）
- superpowers＝TDD 執行閉環（`test-driven-development`、`using-git-worktrees`、`verification-before-completion`、`finishing-a-development-branch`）
- 每層結束寫一份交接檔，標頭固定：`目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`。下一層只讀 `CLAUDE.md` + 該交接檔，需要細節時依其中路徑精準讀取。

## 先讀什麼
1. `CLAUDE.md`（本檔經它匯入）
2. 你的 Kandev task 描述裡指名的交接檔
3. `MEMORY.md` 索引中與你的 task 有關的那一條
