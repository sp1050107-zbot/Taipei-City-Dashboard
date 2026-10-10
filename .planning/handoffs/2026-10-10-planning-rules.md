# 交接：Taipei｜規劃與規則

撰寫：原 session「Taipei｜規劃與規則」（工作目錄 `~`），2026-10-11 核對總管草稿 `~/control-tower/handoffs/Taipei｜規劃與規則.md` 後改正。

**接手方式**：新 session 的工作目錄必須是 `~/Taipei-City-Dashboard`（這樣 `CLAUDE.md`／`AGENTS.md` 才會自動載入）。開工先讀**本檔**、`~/control-tower/BASELINE.md`、`~/control-tower/dispatch/Taipei｜規劃與規則.md`（派工以該資料夾為準；session 之間的訊息只是提醒，不是派工）。

## 目標

負責 Taipei 的文件與規則：spec、決定記錄（`docs/decisions/`）、`AGENTS.md`／`CLAUDE.md`、`MEMORY.md`、`GLOSSARY.md`、`docs/agents/`、`docs/qa/`、`.scratch/` 的 spec 與票。實作與環境操作屬於另一個 session「Taipei｜實作與營運」。

## 已決定

- **權限分級**照 `~/control-tower/BASELINE.md`：L0（唯讀、文件、只含文件的本機 commit）直接做；L1（改 `CLAUDE.md`／`AGENTS.md`／已 Accepted 的決定記錄、建卡或移卡、本機合併到 `develop`）需派工逐字引用大里原話；L2（push、憑證、刪除、改設定）只有大里在本 session 直接下令才做。
- **Codex 相互驗證**：唯一來源是 `~/Documents/sp1050107-zbot/kandev-assistant/docs/plans/2026-09-26-agent-collaboration-evaluation.md` §8.1；Taipei 的 `docs/decisions/0004-codex-independent-review-and-cross-verification.md` 只引用。整合分支合併回 `develop` 前，`/code-review` 之外**還要過 Codex**（`AGENTS.md` 規則 1）。
- **QA 採 Q2 縮小版**（2026-10-10，`5bf896ec`）：流程在 `docs/qa/README.md`；不建 Q workflow、不讓欄位自動啟動 agent。原設計 spec 與計畫已標為縮小範圍／不再執行。
- **Kandev 是大里回查進度用的看板（強制）**：新增票、改 `Status:`、或票多了 `## Answer` 之後，同一回合執行 `python3 docs/agent-workflow/kandev_bootstrap.py` 並用 `python3 docs/agent-workflow/test_kandev_bootstrap.py` 驗證（`AGENTS.md`「追蹤與領域文件」）。
- **祕密**：commit 前用 `mapbox-key.txt` 的完整字串比對 staged diff，只回報有／無；`docker/.env` 不讀不印（`AGENTS.md` 規則 4）。
- **Phase 2 狀態（2026-10-11 查證）**：`.scratch/phase2-hybrid-dev/issues/` 的 12 張票全部 `resolved`；Kandev workspace `taipei-city-dashboard` 有 12 張可見卡，全部 `COMPLETED`，`test_kandev_bootstrap.py` → `PASS`。舊的 P1-01…08、P2-00 卡已封存（大里同意，不再動）。`develop` 與 origin 同步在 `5bf896ec`。

## 未決定

- **P6**：停用 office-hours／plan-*review／autoplan，並在閘門加 Codex；要改 `CLAUDE.md`，等大里決定（L1）。
- **Phase 1 舊文件的「不接 Codex」**：`docs/superpowers/plans/2026-10-06-phase1-local-deploy.md:462`、`docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md:140,160` 仍寫 Phase 1 當時的限定。是否比照 `0001` 加一行「由 0004 取代」，2026-10-08 已請總管決定，尚無回覆。
- **QA 票的看板命名與位置**：`.scratch/qa/issues/` 的卡會以 `qa-NN` 為前綴、落在 `B 客製開發`（`kandev_bootstrap.py` 的 `FEATURE_PREFIX`、`TICKET_WORKFLOW`）。要改需另開票，走 worktree＋TDD（派工第 3 版）。

## 下一步

- 待命。開工讀派工檔；只做 L0 與有引用大里原話的 L1；完成或卡住時寫 `~/control-tower/reports/Taipei｜規劃與規則-<YYYY-MM-DD>.md`（同一天追加），不改派工檔、不 commit control-tower。
- 注意：這個原 session 的自動記憶在 `~/.claude/projects/-Users-opsai/memory/`；新 session 在 `~/Taipei-City-Dashboard` 開，記憶目錄不同，讀不到那裡的筆記。需要長期遵守的規則都已寫進 `AGENTS.md`，以它為準。

## 關鍵檔案路徑

- 規則：`AGENTS.md`、`CLAUDE.md`、`MEMORY.md`、`GLOSSARY.md`、`docs/agents/issue-tracker.md`
- 決定記錄：`docs/decisions/0001`–`0004`
- 流程：`docs/qa/README.md`、`docs/agent-workflow/enterprise-workflow-skill-map.md`、`docs/agent-workflow/standalone-flows-per-project.md`
- 票與 spec：`.scratch/phase2-hybrid-dev/`；問題總表：`docs/agent-workflow/phase1-issue-log.md`
- 看板同步：`docs/agent-workflow/kandev_bootstrap.py`、`docs/agent-workflow/test_kandev_bootstrap.py`
- 總管側：`~/control-tower/BASELINE.md`、`STATUS.md`、`dispatch/`、`reports/`
