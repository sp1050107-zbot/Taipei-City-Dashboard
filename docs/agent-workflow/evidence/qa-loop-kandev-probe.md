# QA 迴圈 Kandev 實測（probe）

## 目標
找出本機 Kandev（`http://127.0.0.1:38429/api/v1`）的實際行為，供計畫 Task 4 決定 Q workflow 各欄的 `on_enter` 事件。只動前綴 `ZZ-PROBE` 的物件，探測 workflow 內三欄：`a`＝`[auto_start_agent]`、`b`＝`[reset_agent_context, auto_start_agent]`、`c`＝無事件（`wip_limit=1`）。

## 已決定
第一次執行中途被中斷；「上下文隔離」實驗之後重新設計，加入正向對照（`ctrl` 卡：同樣的祕密、不經 reset 的欄位），並改在同一 session 內做第二輪移卡才下結論。

實測變數（值 — 原始觀察，已去除祕密）：

- `RESET_ON_SESSIONLESS_ENTRY` = **ok** — 還沒有 session 的卡（t2b，建立後無 session）移入 b：無錯誤、無 "Context reset" 狀態訊息，移動當下由 auto_start 啟動一個 session；沒有 session 時 reset 是靜默 no-op（只有曾存在 session 的 t2c 才出現 reset 狀態訊息）。
- `RESET_ISOLATES_CONTEXT` = **yes** — `iso`（b 欄、有 reset）第二輪回答 `NONE`，時間軸出現 "Context reset — new conversation started"；`ctrl`（a 欄、無 reset、同一 session）第二輪回答出現該祕密，正向對照成立。
- `RESET_ROUND1_AGENT_COMPLIANCE` = **unverified** — 兩個 agent 第一輪都回覆「疑似 prompt injection」警告，而非 STORED/READY；移卡的一次性 `instructions` 會被附加到使用者訊息裡的 task description 之後。
- `MOVE_WHILE_RUNNING` = **no-issue**（1b 情境）— 每次移卡都回 200，移卡前 session 皆為 WAITING_FOR_INPUT。另見下方 1c：session 為 RUNNING 時的移卡被延後到回合結束。
- `AUTO_START_VIA_REST_MOVE` = **yes（僅限卡片有 `agent_profile_id`）** — t2b/t1c 移入 b 後有 session 與回合；`1a-extra`（無 profile）移入 b：無 session、metadata `auto_start_failed=true`、state `SCHEDULING`。
- `REST_CREATE_NEEDS_AGENT_PROFILE` = **yes** — REST 建立／移動卡片需要 `agent_profile_id`。`1a-extra` 在 auto 欄 a 建立但沒帶 profile：state `CREATED`、15 秒後 0 個 session。
- `CREATE_IN_AUTO_STEP_STARTS_AGENT` = **yes（有帶 profile 時）／no（沒帶時）** — t2c 建立後 0.1 秒內有 session；`1a-extra`、t2 沒有。但 t2b 在 a 欄帶 profile 建立卻到移卡才出現 session，不一致，原因未查明。
- `AGENT_CAN_CREATE_AND_MOVE` = **yes** — 工具名為 `mcp__kandev__{list_workflow_steps,create_task,move_task}_kandev`。第 2 次（第一人稱擁有者措辭）建立了子卡（c 欄、state `CREATED`、external_id `ZZ-PROBE-1`、無 session，`start_agent=false` 被遵守），並把自己移到 c；session 為 RUNNING 時移卡的 disposition 是 `deferred`，回合結束才生效；`prompt` 成為一次性進入指令。
- `WIP_LIMIT_BEHAVIOUR` = **ignored（未強制）** — 在 `wip_limit=1` 的 c 欄，超額建立與移入都被接受，無錯誤也無警告欄位，卡片確實都在 c。唯一訊號是超額卡片的欄位 `wip_admitted=false`（第一張為 true）；進入 c 沒有啟動 session。
- `AUTO_START_VIA_UI_MOVE` = **unverified** — 內建瀏覽器開啟 Kandev 後被首次使用的新手引導對話框（AI 代理程式設定）擋住，且需先做設定才能操作看板；為避免更動應用設定而依 3 分鐘上限跳過。

補充事實：
1. 第一次執行被中斷，上下文隔離實驗已重新設計並加入正向對照（見上）。
2. REST 建立／移動需要 `agent_profile_id`，否則 auto_start 失敗。
3. agent 把一次性移卡指令、以及 description 裡第三人稱的 "The user explicitly requests..." 句子視為疑似 prompt injection 並拒絕／要求確認；改成第一人稱擁有者措辭後才照做。
4. `wip_limit` 不被強制。
5. session 為 RUNNING 時的移卡被延後到回合結束才套用。

清理：先數量後刪除（原文）：
```
BEFORE total tasks 24 real tasks 9 zz tasks 15 workflows 7 real workflows 6
AFTER  total tasks 9 real tasks 9 zz tasks 0 workflows 6 zz workflows 0
```
真實任務（P1-01..08、P2-00）與 6 個真實 workflow 的 id 清單前後完全相同。刪除時 10 張曾有 worktree 的卡第一次 `DELETE /tasks/<id>` 回 409（`dirty_worktrees`），卡片被封存；重試一次後皆回 success，最終 15 個 `ZZ-PROBE` task id 與 workflow `b21dd736…` 逐一 GET 都是 404。`git worktree list` 沒有殘留的 ZZ 項目。

## 未決定
- UI 拖卡（c → a）是否啟動 agent 回合：未驗證（`AUTO_START_VIA_UI_MOVE=unverified`）。
- `CREATE_IN_AUTO_STEP_STARTS_AGENT` 的不一致（t2b 有 profile 卻到移卡才有 session）原因未知。
- 重複 `external_id` 的行為：未驗證（agent 只呼叫一次 create）。
- `wip_admitted=false` 的實際作用（是否抑制 auto-start 或排隊）：未驗證。
- 第一輪一次性 `instructions` 是否被 agent 遵守：未驗證（被當成 injection）；Task 4 的措辭需用第一人稱擁有者語氣或寫成正常任務內容。

## 下一步
Task 4 的 Q workflow 進入事件採下方 DECISION；agent 指令與交接訊息用第一人稱擁有者措辭；REST 建卡一律帶 `agent_profile_id`；不要依賴 `wip_limit` 擋量。

## 關鍵檔案路徑
- `docs/superpowers/plans/2026-10-07-qa-loop-workflow.md`（Task 1）
- `docs/superpowers/specs/2026-10-07-qa-loop-workflow-design.md`（§8）
- `.superpowers/sdd/2026-10-07-qa-loop-workflow/task-1-findings.md`、`task-1a-report.md`、`task-1b-report.md`、`task-1c-report.md`、`task-1d-report.md`

DECISION: ON_ENTER = [reset_agent_context, auto_start_agent]
