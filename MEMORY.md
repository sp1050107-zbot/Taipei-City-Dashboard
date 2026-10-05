# MEMORY — 長期記憶索引（只放索引，細節在連結檔）

## 規格與計畫
- [設計 spec](docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md) — 目標、三層分工、worktree 紀律、Phase 1/2
- [Phase 1 計畫](docs/superpowers/plans/2026-10-06-phase1-local-deploy.md) — 10 個 Task，對應 Kandev 種子 task P1-01…P1-08

## 已定案決定
- 檔名用 AGENTS.md；.planning/ 納入 git；本輪不接 Codex；不設 AI/LLM 金鑰；Mapbox 用使用者自己的 token（`mapbox-key.txt`，不入 git）。
- 本機 git 尚未設定 user.name/email（使用者決定），不 push。

## 踩坑與事實（實測/讀碼得到）
- BE 啟動必載本地嵌入模型與 onnxruntime（`Taipei-City-Dashboard-BE/app/app.go:47`，失敗即 `log.Fatalf`）→ Docker 的 `model_export` 階段是必經，沒有「純 golang image」備案。
- 新建的 Kandev workspace 任務前綴是 `KAN`（與既有 workspace 相同），靠標題 `P1-xx` 辨識。
- 自建 Kandev 新 workflow 的 steps 查詢回 `null` 而非 `[]`（`kandev_bootstrap.py` 已處理）。

- Phase 1 決策記錄：[0001](docs/decisions/0001-phase1-deploy-approach.md) — 12 條 ruling（待使用者確認）：不啟動 nginx/pgAdmin/vector-db-upgrade、先 build 再 up、init 只做一次、就緒探測用 `/api/v1/dashboard/`。
- Docker Desktop 只配 8.3 GB 記憶體，BE 要同時 Go 編譯與載入 e5-base 模型，可能吃緊。
- init 容器 `Exited (0)` 不代表成功（`app/initial/initial.go` 吞錯、`psql -f` 無 `ON_ERROR_STOP`）；以資料列數驗收。
- **Phase 2 注意**：init 容器在綁定掛載上用 Alpine 跑 `npm ci`，會把 musl 版原生二進位寫進主機 `Taipei-City-Dashboard-FE/node_modules`；在主機直接 `npm run dev` 前必須刪除並重裝。

## 目前狀態
- Phase 1 進行中：Task 1–4 完成（Kandev、文件三件組、程式碼地圖、gstack 審查），下一步 Task 5（`make-env.sh`，worktree）。
