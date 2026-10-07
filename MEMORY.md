# MEMORY — 長期記憶索引（只放索引，細節在連結檔）

## 規格與計畫
- [設計 spec](docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md) — 目標、三層分工、worktree 紀律、Phase 1/2
- [Phase 1 計畫](docs/superpowers/plans/2026-10-06-phase1-local-deploy.md) — 10 個 Task，對應 Kandev 種子 task P1-01…P1-08

- [Phase 1 驗收證據](docs/agent-workflow/evidence/phase1-verification.md) — 逐項實測輸出、QA 截圖、已知差異
- [Phase 1 學習萃取](.planning/codebase/LEARNINGS-phase1.md) — 決策/教訓/模式/意外
- [交接檔](.planning/HANDOFF-phase1.md) — 下一個 session 先讀這份
- [Phase 1 問題與處理總表](docs/agent-workflow/phase1-issue-log.md) — 環境前置、各 Task、最終審查的每個狀況、處理方式、狀態；含 15 條 executor ruling 與 13 個 deferred Minor
- [知識圖說明](CLAUDE.md#知識圖understand-anything) — `.ua/` 圖的建法、補強指令；`.vue` 檔無 parser（摘要為推斷）

## 已定案決定
- 檔名用 AGENTS.md；.planning/ 納入 git；本輪不接 Codex；不設 AI/LLM 金鑰；Mapbox 用使用者自己的 token（`mapbox-key.txt`，不入 git）。
- git 身分沿用自動偵測的 `opsai@…local`，不另設 user.name/email（使用者 2026-10-07 同意）；不 push。
- `.ua/`（Understand-Anything 知識圖）視為非程式碼，可直接在 `develop` commit（使用者 2026-10-07 同意，已寫入 AGENTS.md 規則 2）。

## 踩坑與事實（實測/讀碼得到）
- BE 啟動必載本地嵌入模型與 onnxruntime（`Taipei-City-Dashboard-BE/app/app.go:47`，失敗即 `log.Fatalf`）→ Docker 的 `model_export` 階段是必經，沒有「純 golang image」備案。
- 新建的 Kandev workspace 任務前綴是 `KAN`（與既有 workspace 相同），靠標題 `P1-xx` 辨識。
- 自建 Kandev 新 workflow 的 steps 查詢回 `null` 而非 `[]`（`kandev_bootstrap.py` 已處理）。

- Phase 1 決策記錄：[0001](docs/decisions/0001-phase1-deploy-approach.md) — 12 條 ruling（待使用者確認）：不啟動 nginx/pgAdmin/vector-db-upgrade、先 build 再 up、init 只做一次、就緒探測用 `/api/v1/dashboard/`。
- Docker Desktop 只配 8.3 GB 記憶體，BE 要同時 Go 編譯與載入 e5-base 模型，可能吃緊。
- init 容器 `Exited (0)` 不代表成功（`app/initial/initial.go` 吞錯、`psql -f` 無 `ON_ERROR_STOP`）；以資料列數驗收。
- **Phase 2 注意**：init 容器在綁定掛載上用 Alpine 跑 `npm ci`，會把 musl 版原生二進位寫進主機 `Taipei-City-Dashboard-FE/node_modules`；在主機直接 `npm run dev` 前必須刪除並重裝。

- **第一次 BE build 要預留 1 小時以上**：arm64 解析到 CUDA 版 PyTorch（數 GB），第二次靠 BuildKit 快取只要約 10 分鐘；背景指令時間上限請設最大值 7200000 ms。
- 兩個 PostGIS 容器是 amd64 映像在 arm64 上以模擬執行（上游 tag 無 arm64 版）。
- 就緒探測用 `GET /api/v1/dashboard/`（帶斜線）；不帶斜線是 301。`up` 後約 120 秒才回 200。
- 前端 `index.html:31,39` 會把瀏覽資料送到上游的 GA（`G-0KD9XLZ7W3`），B 階段第一批客製候選。
- 新 Kandev workspace 任務前綴也是 `KAN`，標題 `P1-xx` 辨識。
- `task-done` 要在整合 checkout 執行，不要在 worktree 內跑（ledger 會寫到 worktree 自己的目錄）。
- 防護 hook 禁止代理讀 `docker/.env`（任何 `.env`）；`mapbox-key.txt` 可在 shell 內拿來比對（例如檢查 diff 有沒有洩漏）但永不印出。需要管理員密碼請使用者自己查：`grep DASHBOARD_DEFAULT docker/.env`。

## 目前狀態
- **Phase 1 已部署，驗收 3/4 項通過；管理員登入尚待使用者驗證**（Task 1–10 皆完成）：FE 8080、BE 8088、兩個 DB（示範資料已載入）、Redis、Qdrant 皆運行；瀏覽器 QA 三頁 PASS（含預期的 3D 建物/行政區缺口）。
- **待使用者處理**：(1) 核准把 `feature/make-env` 合併進 `develop`（尚未合併，腳本目前只在 worktree `~/Taipei-City-Dashboard-worktrees/make-env`）；(2) 自行驗證管理員登入；(3) 確認決策記錄的 12 條 ruling。
- **知識圖已建並 commit**（2026-10-07）：`.ua/knowledge-graph.json`，1010 檔、2031 節點、3363 邊、10 層、13 步導覽，說明為 zh-TW；已補 40 個 Gin 路由節點與 `.vue` import 邊（工具 `~/Understand-Anything/scripts/augment-gin-vue.mjs`，`/understand` 增量更新後要重跑）。已知限制：99 個 `.vue` 檔無 parser，摘要為依檔名推斷；DE 的 `job_config.json` 摘要為部分讀取。
- **下一步**：寫 Phase 2（混合式開發）計畫；候選客製：移除 GA 追蹤、MapLibre 替換（選配）。
