# 0002 Phase 1 與 Phase 2 同一時間只跑一種

日期：2026-10-07　來源：`/grill-with-docs` 第 2、3 輪（使用者逐題確認）

## 背景
Phase 1 的容器 `dashboard-fe`（主機 8080）與 `dashboard-be`（主機 8088）正在運行。Phase 2 要讓主機原生的 FE/BE 使用同樣的埠。compose 檔用固定 `container_name`，AGENTS.md 規則 7 規定同一台機器只能有一組堆疊。

## 已決定
1. 跑 Phase 2 期間，**停掉 `dashboard-fe` 與 `dashboard-be`**；`redis`、`postgres-data`、`postgres-manager`、`qdrant` 繼續運作。
2. 主機原生 FE 用 8080，BE 用 `GIN_PORT=8088`，與 Phase 1 相同。
3. `postgres-data` 開放主機埠 5433、`redis` 開放 6379，兩者都只綁定 127.0.0.1（loopback），不對區網開放（`postgres-manager` 已是 5432）。重建這兩個容器前先問使用者；volume 保留，不重跑初始化（規則 9）。
4. 文件明寫「同一時間只跑 Phase 1 或 Phase 2」。
5. runbook 要有「回到 Phase 1」一節：停掉主機 FE/BE，重新啟動兩個容器；多開的 5433、6379 不需還原。

## 否決的做法
- Phase 1 與 Phase 2 並行、用不同埠：違反規則 7，且主機與容器的資料庫連線容易混淆。
- 另建一個 Phase 2 專用 compose 專案：固定 `container_name` 會衝突。

## 未決定 / UNVERIFIED
- 主機 Node 26 / Go 1.27.1 與專案的相容性（決定：前端固定 Node 21，後端 `GOTOOLCHAIN=local`，仍待實測）。
- macOS ONNX Runtime 1.23.2 與專案 Go 綁定的相容性。
