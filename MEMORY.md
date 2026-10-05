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

## 目前狀態
- Phase 1 進行中：Task 1（Kandev）完成，Task 2（文件三件組）進行中。
