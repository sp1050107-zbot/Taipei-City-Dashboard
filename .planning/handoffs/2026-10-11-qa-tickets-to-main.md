# 交接：QA 試點的五張票 → Taipei｜主線

## 目標
把 Taipei｜QA 試點發現的五張 bug 票併入 `develop`、同步到 Kandev 看板，並依序排修復。交接人：Taipei｜QA；依據：大里 2026-10-11 在 QA session 說「請把這五張票交給『Taipei｜主線』」。

## 已決定
- 分支 `feature/qa-run-2026-10-11-1`（從 `develop` @ `92c8057d` 開出）只含文件：四份巡檢報告、五張票、證據檔、`docs/qa/README.md` 第 7 步（試點差異寫回，大里同意）。未 push、未動 `develop`、未動看板。
- 五張票（皆 `Status: ready-for-agent`，Blocked by 無）：
  - 01 viewpoint 越權讀寫刪，且回應帶出他人 email（S2，資安類）
  - 02 contributor 序號未同步，首次新增必回 500；issues、components 同風險（S2；根因疑在 `db-sample-data/dashboardmanager-demo.sql`）
  - 03 `ai-summary/trigger` 未掛管理者驗證，匿名越過驗證（S2，已實測；本環境 Airflow 未設定所以沒真的觸發 DAG）
  - 04 改別人的個人儀表板回 500 而非 403／404（S3）
  - 05 登入 email 格式錯誤回 `{"error":{}}`（S4）
- 大里決定：QA 帳號 `qa-admin`、`qa-editor` 保留在資料庫；不測 editor 畫面；測試資料已清空（資料庫核對 `qa-3` 殘留 0）。

## 未決定
- 併入 `develop` 的時機與方式（AGENTS.md 規則 1、2：文件類可直接在整合 checkout commit；是否逐 commit 併或 squash，由主線依大里指示）。
- 修復順序與是否走 `/plan-eng-review`：QA README 規定 S1 與跨前後端問題先做決策；01、03 是資安類，建議先交 Codex 審查（決策 0004）。
- 票 02 的修法位置：改示範 SQL（加 `setval`）、還是改初始化流程；已初始化的環境要不要補一次性修正（規則 9：初始化不重跑）。
- 票 03 在有設定 Airflow 的部署上的實際影響，需要有 Airflow 的環境才能實測。
- 這五張票的 Kandev 卡片與欄位（`Status: ready-for-agent` → Backlog），以及是否要寫 `kandev_bootstrap.py` 同步後的驗證。
- 是否保留或移除 QA 專用帳號（目前保留，移除 SQL 在回報檔）。

## 下一步
1. 在整合 checkout 檢視分支差異（只有文件），決定併入方式並併入 `develop`。
2. 併入後同一回合執行 `python3 docs/agent-workflow/kandev_bootstrap.py` 與 `python3 docs/agent-workflow/test_kandev_bootstrap.py`（AGENTS.md 強制規則），確認五張票各有一張卡、在 Backlog。
3. 排修復：每張票在自己的 worktree、先寫失敗測試；修復者不得自己複驗，複驗另用一個 session（QA README 第 3 節）；合併前 `/code-review` 加 Codex 獨立審查。
4. 修復完成後可請 Taipei｜QA 依票上的重現步驟複驗（QA 帳號仍在；腳本見證據檔）。

## 關鍵檔案路徑
- 分支：`feature/qa-run-2026-10-11-1`；worktree：`~/Taipei-City-Dashboard-worktrees/qa-2026-10-11-1`
- 票：`.scratch/qa/issues/01-viewpoint-idor.md`、`02-contributor-sequence.md`、`03-ai-summary-trigger-noauth.md`、`04-patch-other-dashboard-500.md`、`05-login-error-empty.md`
- 報告：`docs/qa/runs/2026-10-11-1.md` 到 `-4.md`
- 證據與重現腳本：`docs/qa/evidence/qa-3/`（`probe-1.py`、`probe-2.py` 讀 `~/.qa-secrets/taipei-qa.env`，該檔不在 repo）
- 回報檔：`~/control-tower/reports/Taipei｜QA-2026-10-11.md`
- QA 流程：`docs/qa/README.md`
