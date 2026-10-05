# Phase 1 交接（GSD → 下一個 session）

## 目標
Phase 1（本地 Docker 全容器部署，供 A 學習研究與 B 客製開發）已完成並有實測證據。下一個 session 的工作是規劃並執行 Phase 2（混合式開發環境）。只需讀 `CLAUDE.md` + 本檔；細節依下方路徑讀取。

## 已決定
- 運行中：`redis postgres-data postgres-manager qdrant dashboard-fe dashboard-be`（不含 nginx、pgAdmin、vector-db-upgrade）。FE `http://localhost:8080`、BE `http://localhost:8088`。
- BE 嵌入模型為必經（`Taipei-City-Dashboard-BE/app/app.go:47`）；`dashboard-be-dev:latest`（3.01 GB）已建好，重 build 靠快取約 10 分鐘。
- init 一次性、不重跑；重置＝刪 `postgres_data`、`postgres_manager_data` volume。
- compose 只在整合 checkout 執行（固定 `container_name`）。
- 12 條 ruling 見 `docs/decisions/0001-phase1-deploy-approach.md`（待使用者確認）。

## 未決定
- `feature/make-env` 合併進 `develop`：等使用者核准。
- 管理員登入未驗證（防護 hook 禁止代理讀 `docker/.env`）。
- Phase 2 範圍：混合式（FE `npm run dev`、BE `go run` 在主機）；onnxruntime 在 Apple Silicon 原生是否可行未驗證；FE `node_modules` 目前是 Alpine 容器裝的 musl 版，主機執行前必須刪除重裝；埠綁定仍是 `0.0.0.0`。
- 候選客製：移除/關閉 `index.html` 的 GA 追蹤；MapLibre + OpenFreeMap（選配）。

## 下一步
1. 使用者核准後合併 `feature/make-env`，並移除 worktree：`git worktree remove ~/Taipei-City-Dashboard-worktrees/make-env && git branch -d feature/make-env`。
2. 用 superpowers `writing-plans` 寫 Phase 2 計畫（先 gstack `/plan-eng-review` 決策、GSD 背景已備）。
3. 把 Phase 2 的任務種進 Kandev workflow `B 客製開發`（`python3 docs/agent-workflow/kandev_bootstrap.py` 目前只種 A 的 8 張）。

## 關鍵檔案路徑
- `docs/agent-workflow/evidence/phase1-verification.md`、`docs/agent-workflow/evidence/qa/`
- `docs/decisions/0001-phase1-deploy-approach.md`
- `.planning/codebase/`（含 `LEARNINGS-phase1.md`）
- `docker/docker-compose*.yaml`、`docker/.env`（被忽略，勿讀勿 commit）
- `~/Taipei-City-Dashboard-worktrees/make-env`（未合併的 `make-env.sh` 與測試，commit `bdfbe6c`）
