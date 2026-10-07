# QA 迴圈 Kandev 實測（probe）

## 目標
找出本機 Kandev（`http://127.0.0.1:38429/api/v1`）的實際行為，供計畫 Task 4 決定 Q workflow 各欄的 `on_enter` 事件。只動前綴 `ZZ-PROBE` 的物件，探測 workflow 內三欄：`a`＝`[auto_start_agent]`、`b`＝`[reset_agent_context, auto_start_agent]`、`c`＝無事件（`wip_limit=1`）。


## 已決定
第一次執行中途被中斷；「上下文隔離」實驗之後重新設計：加入正向對照（同樣的祕密、但進入不做 reset 的欄位），並改在同一 session 內做第二輪移卡才下結論。

實驗卡片圖例（探測用卡片，皆已刪除；以下只用角色名稱）：
- 「無 session 卡」：在 auto 欄建立後仍沒有 session 的卡（帶 profile）。
- 「有 session 卡」：建立後立即有 session 的卡（帶 profile）。
- 「帶 profile 卡」：建立時有送 `agent_profile_id` 的卡；「無 profile 卡」：沒送的卡。
- 「測試卡」：進入 b 欄（有 reset）的隔離實驗卡；「對照卡」：進入 a 欄（無 reset）、其餘條件相同。
- 「MCP 卡」：由 agent 透過 MCP 工具建子卡並移動自己的卡；第 1 次（description 內第三人稱措辭）與第 2 次（第一人稱擁有者措辭）是兩張不同的卡。

實測變數（值 — 原始觀察，已去除祕密）：

- `RESET_ON_SESSIONLESS_ENTRY` = **ok** — 觀察：無 session 卡移入 b 欄時，沒有錯誤、沒有 "Context reset" 狀態訊息，移動當下由 auto_start 啟動一個 session；有 session 卡移入 b 時則出現 "Context reset" 狀態訊息與新的使用者訊息。推論（inferred，非直接觀察）：沒有 session 時 reset 等同無作用。
- `RESET_ISOLATES_CONTEXT` = **yes** — 測試卡（b 欄、有 reset）第二輪回答 `NONE`，時間軸出現 "Context reset — new conversation started"；對照卡（a 欄、無 reset、同一 session）第二輪回答出現該祕密，正向對照成立。
- `RESET_ROUND1_AGENT_COMPLIANCE` = **unverified** — 兩張卡的 agent 第一輪都回覆「疑似 prompt injection」警告，而非 STORED/READY；移卡的一次性 `instructions` 會被附加到使用者訊息裡的 task description 之後。
- `MOVE_WHILE_RUNNING` = **no-issue**（隔離實驗情境）— 每次移卡都回 200，移卡前 session 皆為 WAITING_FOR_INPUT。session 為 RUNNING 時的移卡見 `AGENT_CAN_CREATE_AND_MOVE`：被延後到回合結束。
- `AUTO_START_VIA_REST_MOVE` = **yes（帶 profile 時）** — 帶 profile 的卡移入 b 後有 session 與回合；無 profile 卡移入 b：無 session、metadata `auto_start_failed=true`、state `SCHEDULING`。
- `REST_CREATE_NEEDS_AGENT_PROFILE` = **yes（僅一個實驗的觀察，見未決定）** — 一張在 auto 欄 a 建立、沒帶 `agent_profile_id` 的卡：state `CREATED`、15 秒後 0 個 session，之後移入 b 也只得到 `auto_start_failed=true`。其他無 profile 卡後來也有了 session，來源不明（見未決定），所以「沒 profile 就一定沒 agent」不是乾淨的結論。
- `CREATE_IN_AUTO_STEP_STARTS_AGENT` = **yes（帶 profile 時，多數情況）／no（無 profile 的實驗卡）** — 有 session 卡建立後 0.1 秒內有 session；無 profile 實驗卡建立後沒有（另見未決定：三張無 profile 卡後來也有 session，來源不明）。但無 session 卡（帶 profile、在 a 欄建立）卻到移卡才出現 session，不一致，原因未查明。
- `AGENT_CAN_CREATE_AND_MOVE` = **yes** — 工具名為 `mcp__kandev__{list_workflow_steps,create_task,move_task}_kandev`。第 2 次 MCP 卡（第一人稱擁有者措辭）建立了子卡（c 欄、state `CREATED`、external_id `ZZ-PROBE-1`、無 session，`start_agent=false` 被遵守），並把自己移到 c；session 為 RUNNING 時移卡的 disposition 是 `deferred`，回合結束才生效；`prompt` 成為一次性進入指令。第 1 次 MCP 卡（第三人稱措辭）被 agent 拒絕並要求確認，未呼叫任何工具，也沒有權限錯誤。
- `WIP_LIMIT_BEHAVIOUR` = **ignored（未強制）** — 在 `wip_limit=1` 的 c 欄，超額建立與移入都被接受，無錯誤也無警告欄位，卡片確實都在 c。唯一訊號是超額卡片的欄位 `wip_admitted=false`（第一張為 true）；進入 c 沒有啟動 session。
- `AUTO_START_VIA_UI_MOVE` = **unverified** — 內建瀏覽器開啟 Kandev 後被首次使用的新手引導對話框（AI 代理程式設定）擋住；為避免更動應用設定而依 3 分鐘上限跳過。

補充事實：
1. 第一次執行被中斷，上下文隔離實驗已重新設計並加入正向對照（見上）。
2. REST 建立／移動時，實驗中沒帶 `agent_profile_id` 的卡 auto_start 失敗（單一實驗；見 `REST_CREATE_NEEDS_AGENT_PROFILE`）。
3. agent 把一次性移卡指令、以及 description 裡第三人稱的 "The user explicitly requests..." 句子視為疑似 prompt injection 並拒絕／要求確認；改成第一人稱擁有者措辭後才照做。
4. `wip_limit` 不被強制。
5. session 為 RUNNING 時的移卡被延後到回合結束才套用。

清理：先數量後刪除（原文）：
```
BEFORE total tasks 24 real tasks 9 zz tasks 15 workflows 7 real workflows 6
AFTER  total tasks 9 real tasks 9 zz tasks 0 workflows 6 zz workflows 0
```
真實任務（P1-01..08、P2-00）與 6 個真實 workflow 的 id 清單前後完全相同。刪除時 10 張曾有 worktree 的卡第一次 `DELETE /tasks/<id>` 回 409（`dirty_worktrees`），卡片被封存；重試一次後皆回 success，最終 15 個 `ZZ-PROBE` task id 與探測 workflow 逐一 GET 都是 404。`git worktree list` 沒有殘留的 ZZ 項目。

## 未決定
- UI 拖卡（c → a）是否啟動 agent 回合：未驗證（`AUTO_START_VIA_UI_MOVE=unverified`）。
- 三張第一次執行時建立、沒帶 `agent_profile_id` 的卡，之後都有了 session，來源未記錄、原因不明；這與「沒 profile 就不會啟動 agent」不一致，所以 `REST_CREATE_NEEDS_AGENT_PROFILE` 只是單一實驗的觀察。
- `CREATE_IN_AUTO_STEP_STARTS_AGENT` 的不一致（無 session 卡帶 profile 卻到移卡才有 session）原因未知。
- 重複 `external_id` 的行為：未驗證（agent 只呼叫一次 create）。
- `wip_admitted=false` 的實際作用（是否抑制 auto-start 或排隊）：未驗證。
- 第一輪一次性 `instructions` 是否被 agent 遵守：未驗證（被當成 injection）。

## 下一步
規則（給 Task 4，與上面的觀察分開）：REST 建卡與移卡一律帶 `agent_profile_id`；agent 指令與交接訊息用第一人稱擁有者措辭或寫成正常任務內容；不要依賴 `wip_limit` 擋量；Q workflow 進入事件採下方 DECISION。

## 關鍵檔案路徑
- `docs/superpowers/plans/2026-10-07-qa-loop-workflow.md`（Task 1）
- `docs/superpowers/specs/2026-10-07-qa-loop-workflow-design.md`（§8）

DECISION: ON_ENTER = [reset_agent_context, auto_start_agent]
