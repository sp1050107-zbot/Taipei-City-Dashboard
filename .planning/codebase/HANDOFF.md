# 程式碼地圖交接（GSD → gstack / superpowers）

## 目標
為「Taipei-City-Dashboard 本地部署（A 學習研究）與客製開發（B）」提供共用背景。下一層（gstack Task 4）只需讀本檔 + `CLAUDE.md`，細節按下方路徑精準讀取，不必重讀整個專案。

## 已決定
- 地圖 7 份文件在 `.planning/codebase/`：`STACK.md`、`INTEGRATIONS.md`、`ARCHITECTURE.md`、`STRUCTURE.md`、`CONVENTIONS.md`、`TESTING.md`、`CONCERNS.md`。
- 後端啟動時無條件載入本地 ONNX 嵌入模型與 tokenizer，失敗即 `log.Fatalf`（`Taipei-City-Dashboard-BE/app/app.go:47`、`app/models/qdrant.go:102,130,142`）→ Docker build 的 `model_export` 階段為必經。
- 前端在 Docker 模式下由 Vite 代理 `/api/dev` → `dashboard-be:8080`，並改寫為 `/api/v1`（`Taipei-City-Dashboard-FE/vite.config.js`）。
- 範本預設密碼很弱（`JWT_SECRET=secret`，見 `CONCERNS.md`）；本機用 `make-env.sh` 產生隨機值取代。
- 測試現況：後端僅少量 Go 測試、CI 只 `go build`；前端無測試（見 `TESTING.md`）。

## 未決定
- BE 首次 build（含 Hugging Face 下載）實際耗時與失敗率（Task 8 實測）。
- 無專用 health 端點；就緒判斷暫用 `GET /api/v1/dashboard/`（結尾斜線，否則回 301；Task 8 實測確認）。
- `migrateDB` / `initDashboard` 重跑是否冪等（Task 7 實測）。
- 地圖在無 `VITE_MAPBOXTILE`、無 `/geo_server` 時的實際降級表現（Task 9 實測）。

## 下一步
Task 4：以 gstack `/plan-eng-review` 審 Phase 1 部署做法，寫 `docs/decisions/0001-phase1-deploy-approach.md`。

## 關鍵檔案路徑
- `Taipei-City-Dashboard-BE/app/routes/router.go`（路由群組）
- `Taipei-City-Dashboard-BE/global/global.go`（環境變數與預設值）
- `Taipei-City-Dashboard-BE/app/app.go`（啟動順序）
- `Taipei-City-Dashboard-BE/app/models/qdrant.go`（ONNX 模型載入）
- `Taipei-City-Dashboard-BE/Dockerfile`（`model_export` / `prod` / `dev` 階段）
- `Taipei-City-Dashboard-FE/src/store/mapStore.js`（Mapbox 初始化與圖層）
- `Taipei-City-Dashboard-FE/vite.config.js`（Docker 模式代理）
- `docker/docker-compose.yaml`、`docker/docker-compose-db.yaml`、`docker/docker-compose-init.yaml`、`docker/.env.template`
