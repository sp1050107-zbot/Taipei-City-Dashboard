# GLOSSARY

專案詞彙表。一個詞一行；定義以本專案的用法為準。更新時只增修，不整份改寫。

## 部署與環境
- **Phase 1** — 官方 Docker compose 全容器部署：`redis postgres-data postgres-manager qdrant dashboard-fe dashboard-be`。FE 在主機 8080，BE 在主機 8088。見 `docs/decisions/0001-phase1-deploy-approach.md`。
- **Phase 2** — 混合開發：資料庫、Redis、Qdrant 留在 Docker；FE（`npm run dev`）與 BE（`go run`）跑在 macOS 主機。見 `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`。
- **整合 checkout** — `~/Taipei-City-Dashboard`，`develop` 所在處，也是唯一可執行 `docker compose` 的地方。
- **worktree** — `~/Taipei-City-Dashboard-worktrees/<name>`，分支 `feature/<slug>`；程式碼、腳本、compose、設定只在這裡改。
- **主機原生模式** — FE 或 BE 直接在 macOS 主機執行，不在容器內。
- **整合分支** — `/implement-spec` 把多個子 agent worktree 合併後的單一分支（`feature/<spec-slug>`），驗證通過後才一次合併回 `develop`。

## 後端必要元件
- **ONNX Runtime** — 後端啟動時必載的共享函式庫；缺少時 `log.Fatalf` 結束。路徑由 `ORT_LIBRARY_PATH` 指定（預設 `/usr/lib/libonnxruntime.so`）。
- **嵌入模型** — `intfloat/multilingual-e5-base` 的 ONNX 版，位於 `LM_MODEL_PATH`（`model.onnx` 與 `tokenizer.json`）。啟動必載，沒有備案。
- **AI 元件搜尋** — `POST /component`，查詢 Qdrant。Qdrant 掛掉只讓這個請求回錯，不影響後端啟動；不在 Phase 2 驗收範圍。

## 工作流程
- **票** — `.scratch/<feature>/issues/<NN>-<slug>.md` 的 markdown 檔，是事實來源；有 `Status:` 與 `Blocked by:`。
- **Kandev 卡** — Kandev 看板上的卡片，描述只放對應票檔的路徑，不複製內容；是指標，不是事實來源。
- **前線（frontier）** — 阻擋它的票都已完成、可以開始做的票。
- **交接檔** — 固定五個標頭：`目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`；放 `.planning/handoffs/<YYYY-MM-DD>-<topic>.md` 並 commit。
- **驗證者** — 與實作者不同的全新 session，依 runbook 跑驗收並存證據。
- **決定記錄** — `docs/decisions/NNNN-slug.md`（其他範本稱 ADR）。同一個決定只寫在一處，其他地方用路徑引用。
- **UNVERIFIED** — 沒有指令輸出或檔案行號佐證的事項；必須明寫，不得當成已通過。
