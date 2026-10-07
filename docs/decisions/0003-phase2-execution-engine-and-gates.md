# 0003 Phase 2 以 /implement-spec 執行，以及合併前閘門

日期：2026-10-07　來源：`/grill-with-docs` 第 3 輪（使用者確認）

## 背景
現有 Phase 2 計畫（`feature/p2-00-phase-2-far`，commit `1813acae`）結尾問「Subagent-driven 還是 Native」。新流程另有 `/to-tickets` + `/implement-spec`，功能重疊。AGENTS.md 規則 1 已加入 `/implement-spec` 的例外。

## 已決定
1. 計畫的 8 個 task 轉成 8 張票（`.scratch/phase2-hybrid-dev/issues/`）。阻擋關係：Task 3 依賴 Task 1、2；Task 7 依賴 Task 6；Task 8 依賴 Task 1–7。
2. 用 `/implement-spec` 平行執行前線上的票，各在自己的 worktree 跑 `/tdd`，合併到整合分支。
3. 合併回 `develop` 前的閘門：superpowers `verification-before-completion`、gstack `/review`、gstack `/cso --diff`（重點：祕密、`.env.local`）。
4. 驗收由全新的驗證者 session 做，證據放 `docs/agent-workflow/evidence/phase2/`。「管理員登入」由使用者本人確認，agent 不代為登入。
5. 現有計畫在 spec 通過後隨 `feature/p2-00-phase-2-far` 合併進 `develop`，再用一張票依 spec 修訂；spec 只引用計畫路徑，不重複內容。
6. 成功標準：前端靠 Vite HMR 約 1 秒內更新；後端重啟後幾秒內生效，並記錄實測秒數。不新增後端熱重載工具。
7. 範圍外：Qdrant 填充（`vector-db-upgrade`）與 AI 元件搜尋。

## 否決的做法
- 沿用計畫的 superpowers Subagent-driven：與 `/to-tickets` 的票、Kandev 卡重複，會有兩套任務清單。
- 加 `air` 等熱重載工具：多一個依賴，收益不明。

## 未決定
- 8 張票的 Kandev 卡由誰建立（手動或擴充 `kandev_bootstrap.py`）。
