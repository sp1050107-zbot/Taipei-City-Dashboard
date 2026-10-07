# QA 品質迴圈 Workflow 設計 Spec（QA → Bug → Dev 修 → QA 複驗 → PM 摘要）

日期：2026-10-07　狀態：草案（使用者 2026-10-07 已定三個決定，待審閱後寫實作計畫）
目標 repo：`sp1050107-zbot/Taipei-City-Dashboard`（整合 checkout `~/Taipei-City-Dashboard`，分支 `develop`）
上游文件：`docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md`（三層分工、Kandev 結構、交接協議；本文不重複，只寫差異）

## 1. 目標與範圍

**目標**：讓「QA 持續測試 → 發現 bug → Dev 修 → QA 複驗 → PM 通知」成為可重複的迴圈，並用知識圖（`.ua/knowledge-graph.json`）縮小每一步要讀的範圍，避免每個 session 重讀整個 repo。

**已定決定（使用者 2026-10-07）**
1. 新開第三條 Kanban workflow `Q 品質迴圈`，不併進 `B 客製開發`。
2. QA 先**手動觸發**，跑順之後再談自動化。
3. PM 通知先**寫摘要檔**，不接外部通道。

**範圍內**：Q workflow 的欄位與 prompt、bug 卡格式、知識圖的使用規則、事件與摘要檔、迴圈保護機制。

**範圍外（YAGNI）**：自動排程、Slack/Gmail 等外部通知、多個 QA 並行、每個 worktree 各跑一組服務（待 Phase 2 完成後再評估）、對 `develop` 以外分支的測試、效能與壓力測試。

**成功標準**
1. 使用者建立一張 `QA-RUN` 卡並移入 `QA Run`，QA agent 對運行中的服務做巡檢，產出報告；每個發現對應一張 `BUG` 卡。
2. 一張 BUG 卡能走完 `Reported → Triage → Fix → Merge-ready → Re-verify → Done`，每個欄位的 session 只讀 `CLAUDE.md` 與該卡的交接內容。
3. 複驗用**與修復不同的** session；複驗失敗會退回，退回 2 次後升級給使用者，不會無限循環。
4. 每個事件都留下檔案紀錄；使用者要求時能彙整出當日摘要。
5. 全程不印出、不 commit 任何祕密。

## 2. 前提與限制（影響設計的事實）

| 事實 | 來源 | 對設計的影響 |
|---|---|---|
| 整套服務只有一組 compose，容器名稱固定，只能在整合 checkout 跑 | `AGENTS.md` 規則 7 | QA 只能測 `develop` 上跑著的那一組；**修復合併進 `develop` 後才能複驗** |
| 示範資料庫重置很貴（init 不重跑，要刪 volume 重做） | `AGENTS.md` 規則 9 | QA 測試以唯讀為主；會寫入的測試要用可辨識的資料並自行清除 |
| worktree 只看得到已 commit 的內容 | `AGENTS.md` 規則 6 | bug 的交接內容要寫進卡的描述，證據檔要先 commit 到 `develop` |
| 只有文件類與 `.ua/` 可直接在整合 checkout commit | `AGENTS.md` 規則 2 | QA 報告、事件檔、證據可直接 commit；修復一律走 worktree |
| 圖的限制：99 個 `.vue` 檔只有檔案節點、摘要為推斷；`tested_by` 僅 44 條；資料工程沒有資料流 | `MEMORY.md` | 圖只給「提示」，Triage 與 Fix 仍須讀碼確認，不得把圖當結論 |
| 就緒探測：`GET /api/v1/dashboard/`（帶斜線）回 200，`up` 後約 120 秒才就緒 | `MEMORY.md` | QA 開始前先探測；服務未就緒回報「環境未就緒」，**不算 bug** |

## 3. Workflow 與欄位

Workflow 名稱：`Q 品質迴圈`。每個 task 一個 Claude session，一個 session 只做一個欄位的工作（沿用上游 spec §3）。

| # | 欄位 | 誰（agent 角色） | 觸發 | 主要技能 | 結束時產出 |
|---|---|---|---|---|---|
| 0 | `Backlog` | — | 使用者建卡（起始欄） | — | — |
| 1 | `QA Run` | QA agent | **使用者把 `QA-RUN` 卡移入** | gstack `/qa-only` | 巡檢報告 + 每個發現一張 BUG 卡 |
| 2 | `Reported` | — | BUG 卡進入點（由 QA Run 建立，或使用者手動建） | — | — |
| 3 | `Triage (graph)` | 分流 agent | 卡移入 | 知識圖、`gsd-resume-work` | 嚴重度、所屬層、候選檔案、重複判斷 |
| 4 | `Decide (gstack)` | 決策 agent | 僅 S1/S2、跨層、或被升級的卡 | gstack `/plan-eng-review` | 決策記錄（沿用 `docs/decisions/`） |
| 5 | `Fix (worktree)` | Dev agent | 卡移入 | `systematic-debugging`、`test-driven-development` | worktree 分支上的修復 commit（失敗測試先行） |
| 6 | `Merge-ready` | 使用者 | 卡移入 | `finishing-a-development-branch` | **使用者核准後**本機 merge 進 `develop` |
| 7 | `Re-verify (QA)` | **新的** QA agent | 卡移入 | gstack `/qa-only`、`verification-before-completion` | 複驗結果：PASS 或 FAIL |
| 8 | `Done` | PM agent | 卡移入（`complete_task_on_enter`） | — | 事件檔、圖更新 |
| 9 | `Closed` | PM agent | 重複、不修、無法重現 | — | 事件檔（註明原因） |

**狀態流**

```
QA-RUN: Backlog ──(手動移入)──▶ QA Run ──▶ 產生 BUG 卡 ──▶ Done

BUG:   Reported ─▶ Triage ─┬─(S3/S4 且單一層)──────────────┐
                           └─(S1/S2 或跨層)─▶ Decide ──────┤
                                                           ▼
                    ┌──────────────────────────────────── Fix
                    │                                       │
                    │                                  Merge-ready（使用者核准、合併）
                    │                                       │
                    │                                  Re-verify
                    │            FAIL，退回次數 < 2 ◀───────┤
                    └────────────────────────────           │ PASS
                                                            ▼
                    FAIL 且已退回 2 次 ─▶ Decide（升級）     Done
                    重複／不修／無法重現 ─▶ Closed
```

- `QA-RUN` 卡與 BUG 卡共用同一條 workflow、同一個 Kanban，靠標題前綴辨識：`QA-RUN-<n>`、`BUG-<n>`（Kandev 自動前綴與既有 workspace 相同，沿用 `P1-xx` 的做法）。編號取現有最大值加一。
- Kandev 欄位的 `on_enter` 與 `wip_limit` 設定見 §8。
- 各欄位 prompt 沿用 `kandev_bootstrap.py` 現有風格（`[角色 - 技能] {{task_prompt}}` + 只讀 `CLAUDE.md` 與卡內交接 + 結束條件）。

## 4. 各欄位職責與規則

### 4.1 QA Run
- 開始前先做就緒探測；未就緒則在報告記「環境未就緒」並結束，不開 BUG 卡。
- 測試範圍來自卡的描述（使用者指定）；未指定時，用知識圖與最近的 `develop` commit 算出受影響頁面與 endpoint（見 §5），再加少量抽樣。
- 只測、只報告，**不修**。因此用 `/qa-only`，不用會改碼的 `/qa`。
- 寫入類測試只用可辨識的資料（名稱含 `qa-<run編號>`），結束前清除；無法清除的要在報告中列出。
- 每個發現：先查是否與開啟中的 BUG 卡重複，再開新卡。證據（截圖、curl 輸出，不含祕密）存 `docs/qa/evidence/<BUG編號>/` 並 commit 到 `develop`，之後才建卡。
- 報告存 `docs/qa/runs/<QA-RUN編號>.md`。

### 4.2 Triage
- 讀 `CLAUDE.md` 與 BUG 卡，不重讀整個 repo。
- 以症狀（網址、頁面、endpoint）查知識圖，得到候選檔案鏈（見 §5），寫回卡的描述。
- 判定嚴重度（§6）、所屬層，並比對開啟中的卡是否重複。
- 路由規則：S3/S4 且候選檔案落在**單一層** → 直接進 `Fix`；S1/S2 或候選檔案跨層 → 進 `Decide`；重複、無法重現 → 進 `Closed`。

### 4.3 Fix
- 只在自己的 worktree 工作，不碰整合 checkout（沿用上游 spec §4）。
- 先寫能重現 bug 的失敗測試，再實作到通過。測試要能在 worktree 內單獨跑（不需整套 compose）。
- 修完把「影響範圍」（§5.3）寫進卡的描述，供複驗使用。
- 若 bug 無法用單元層級測試重現（例如純視覺），在卡上說明改用什麼證據，並由複驗 QA 以真實服務驗收。

### 4.4 Merge-ready
- 人工關卡，沿用既有規則：使用者核准後才用 `finishing-a-development-branch` 本機 merge，不 push。
- 合併後使用者（或該欄 prompt）確認 FE 與 BE 都已載入新碼（各自是否自動重載、是否要重建映像尚未實測，見 §8 開放問題 3）才能把卡移入 `Re-verify`。

### 4.5 Re-verify
- 新 session，不得與修復是同一個。
- 執行：(1) 原重現步驟；(2) 卡上「影響範圍」列出的回歸項目。
- 結果寫回卡：PASS → `Done`；FAIL → 附新證據、退回次數加一，退回 `Fix`。退回次數已達 2 次時改進 `Decide` 並標記「升級」，等使用者介入。

### 4.6 Done / Closed
- 寫一個事件檔（§7）。
- `Done` 額外檢查知識圖是否過期（§5.4），過期就在事件檔註明並提示使用者更新。

## 5. 知識圖的使用規則

圖在 `.ua/knowledge-graph.json`；每次 `/understand` 增量更新後要執行 `node ~/Understand-Anything/scripts/augment-gin-vue.mjs ~/Taipei-City-Dashboard`（見 `CLAUDE.md`）。

### 5.1 症狀 → 候選檔案鏈（Triage）
| 症狀類型 | 起點 | 沿圖往下 | 候選 |
|---|---|---|---|
| API 錯誤 | `endpoint` 節點（例如 `GET /api/v1/component/:id/chart`） | `routes` → controller 函式 → `calls` → service → model → `table` | 該鏈上的檔案與中介層（`middleware` 邊） |
| 頁面錯誤 | 路由檔指向的 `.vue` 頁面 | `imports` → 子元件、store、composable | 該頁面的 import 閉包（限深度 2） |
| 資料錯誤 | 資料集編號對應的 DAG 檔 | `imports` → 共用 operator | DAG 與其 operator |

候選清單寫成「檔案路徑 + 一句為何相關」，**標明來源是圖還是讀碼**。圖找不到或 `.vue` 資訊不足時，Triage 要自己讀碼補足，並在卡上註記「圖未涵蓋」。

### 5.2 重複判斷
候選檔案集合與開啟中某張卡重疊超過一半，且症狀描述相近 → 標為疑似重複，附上對方卡號，由 Triage 決定關閉或合併。

### 5.3 影響範圍（Fix → Re-verify）
Dev agent 依修復 diff 的檔案，在圖中反向追（`imports`、`calls`、`routes` 的反方向），列出：受影響的 endpoint、頁面、`tested_by` 測試。複驗 QA 據此決定回歸項目。

### 5.4 圖的新鮮度
每次有修復合併進 `develop`，圖就可能過期。`Done` 欄檢查 `.ua/meta.json` 的 `gitCommitHash` 與 `develop` HEAD 是否一致；不一致時在事件檔寫「圖待更新」。更新由使用者觸發（`/understand` 增量 + 補強腳本），更新結果以文件類 commit 進 `develop`。

### 5.5 查詢方式（待實作計畫確認）
目前沒有現成的圖查詢指令。實作計畫第一個任務要評估：Understand-Anything 的 `/understand-diff`、`/understand-explain` 是否足以涵蓋 §5.1 與 §5.3；不足則寫一個小的查詢腳本（讀 JSON，輸入症狀或檔案，輸出候選鏈）。腳本若放在本 repo 屬程式碼，須走 worktree。

## 6. 交接內容：BUG 卡

BUG 卡的描述就是交接檔，標頭沿用 `目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`，並加下列欄位。各欄位 session 只讀 `CLAUDE.md` 與這張卡。

```
## BUG-<n> <一句話標題>
- 發現於：QA-RUN-<m>（或「手動」）　環境：develop @ <short sha>
- 嚴重度：S? 　所屬層：<layer>　狀態備註：<例：疑似重複 BUG-k>
- 重現步驟：1… 2… 3…
- 預期 / 實際：…
- 證據：docs/qa/evidence/BUG-<n>/…
- 候選檔案（來源：圖／讀碼）：
  - <path> — <為何相關>
- 影響範圍（Fix 完成後填）：endpoint／頁面／測試
- 退回次數：0

## 目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑
…（各欄位 session 結束前更新）
```

**嚴重度**
| 級別 | 定義 | 例 |
|---|---|---|
| S1 | 核心功能完全不可用或資料毀損 | 登入失敗、儀表板整頁空白、BE 啟動崩潰 |
| S2 | 主要功能錯誤但有繞路 | 單一圖表資料錯誤、管理後台某操作失敗 |
| S3 | 次要功能或邊界情況錯誤 | 篩選條件在特定組合失效 |
| S4 | 外觀、文字、非功能性問題 | 錯字、對齊 |

## 7. 事件檔與摘要檔

**事件檔**（一事件一檔，避免多個 session 同時改同一檔造成衝突）：`docs/qa/events/<YYYYMMDD-HHMM>-<BUG或QA-RUN編號>-<事件>.md`，內容 3–8 行：發生了什麼、結果、下一步、需要使用者做什麼。事件包括：`found`、`triaged`、`escalated`、`fixed-merged`、`verified-pass`、`verified-fail`、`closed`、`graph-stale`。

**摘要檔**：`docs/qa/digest/<YYYY-MM-DD>.md`，由 QA Run 結束時、或使用者要求（建一張 `PM-DIGEST` 卡或直接請求）時，**由單一 session** 彙整當天事件檔與 Kandev 卡狀態。固定段落：
1. 今日巡檢範圍與結果
2. 新增 bug（編號、嚴重度、一句話）
3. 已修並複驗通過
4. 退回中（含次數）
5. **需要你決定**（升級項目、待核准合併）
6. 知識圖是否過期

事件檔與摘要檔都是文件，可直接 commit 到 `develop`（`AGENTS.md` 規則 2）。`MEMORY.md` 不逐日記錄，只在里程碑時更新。

## 8. 保護機制與開放問題

**保護機制**
- 複驗失敗最多退回 2 次，第 3 次失敗升級給使用者。
- 同一時間只允許一個 `QA Run` session（服務與資料庫是共用的單一環境）。
- 合併永遠由使用者核准；agent 不 push、不對 upstream 發 PR。
- 任何證據、事件檔、摘要在 commit 前用 `mapbox-key.txt` 的完整字串比對 staged diff（只比對、不印出）；`docker/.env` 不讀不印（`AGENTS.md` 規則 4）。
- 環境未就緒不算 bug，不開卡。

**已查證的問題（2026-10-07，讀 Kandev 原始碼 `~/Documents/sp1050107-zbot/kandev`、`docs/features.md` 與即時 API；尚未在即時環境實測，實測列在實作計畫第一個任務）**

1. **agent 能否在 session 內開卡 → 可以。** Kandev 對一般 task session 自動提供 task 範圍的 MCP（server 名 `kandev`，Claude Code 內工具名形如 `mcp__kandev__create_task_kandev`）。可用工具含 `create_task_kandev`、`move_task_kandev`、`step_complete_kandev`、`list_tasks_kandev`、`list_workflow_steps_kandev`、`update_task_kandev`、`write_task_document_kandev`、`message_task_kandev`。`create_task_kandev` 的關鍵參數：`workflow_id`、`workflow_step_id`（指定落在哪一欄）、`title`、`prompt`（新 session 唯一的上下文）、`start_agent`（預設 true）、`repository_id`、`executor_profile_id`、`external_id`（同一 workspace 內相同值只會建一次，用來防重複建卡，BUG 編號就用它）。
   - 注意：工具說明寫「只用於使用者要求的 Kandev 追蹤工作」。已實測：第三人稱的「使用者已要求…」被 agent 當成提示注入而拒絕，**第一人稱擁有者措辭**（「我是這個看板的擁有者，我要求…」）才照做。`QA-RUN` 卡描述與 QA Run 欄 prompt 都要用第一人稱。
   - 備案（腳本依報告建卡）降為只在實測失敗時啟用。
2. **欄位移入是否自動啟動 session → 只有欄位設了 `on_enter` 動作 `auto_start_agent` 才會。** 即時 API 顯示現有 A 流程所有欄位的 `events` 都是空的，所以 A/B 流程移卡**不會**自動啟動 agent，要手動啟動。Q workflow 要在建欄位時用 `events: {"on_enter": [...]}` 明確設定（`POST /workflow/steps` 接受 `events`、`agent_profile_id`、`wip_limit`）。
3. **session 是否沿用 → 預設沿用。** `auto_start_agent` 以該 task 既有的 session 啟動，上下文會一路帶過各欄位。要「每欄一個乾淨 session」（也是「複驗不同於修復」的條件），要在該欄加 `reset_agent_context`（重啟 agent 子程序、換新 ACP session）。移卡時也可帶一次性交接指示（`instructions`）與 `reset_context` 選項（MCP `move_task_kandev` 的 entry options）。
4. **欄位並行限制**：欄位有 `wip_limit`，可用在 `QA Run`、`Re-verify` 限制同時一個。**已實測：不強制**（只標記 `wip_admitted=false`），因此改由 prompt 規則在開始前檢查。

**欄位的 Kandev 設定（落實上面結論）**

| 欄位 | `on_enter` | 備註 |
|---|---|---|
| Backlog、Reported | 無 | 不啟動 agent |
| QA Run | `auto_start_agent`、`reset_agent_context` | `wip_limit` 1 |
| Triage (graph) | `auto_start_agent`、`reset_agent_context` | |
| Decide (gstack) | `auto_start_agent`、`reset_agent_context` | |
| Fix (worktree) | `auto_start_agent`、`reset_agent_context` | executor 用 `exec-worktree` |
| Merge-ready | 無 | 人工關卡，不啟動 agent |
| Re-verify (QA) | `auto_start_agent`、`reset_agent_context` | `wip_limit` 1；乾淨 session |
| Done、Closed | `auto_start_agent`、`reset_agent_context` | `Done` 設 `complete_task_on_enter` |

**已實測（2026-10-07，證據 `docs/agent-workflow/evidence/qa-loop-kandev-probe.md`）**
1. `claude-acp` session 能呼叫 `create_task_kandev`、`move_task_kandev`、`list_workflow_steps_kandev`；移卡在 session 執行中會延到回合結束才套用。**條件**：提示須為第一人稱擁有者措辭，一次性移卡指示也容易被當成提示注入，真正的交接要寫在卡描述。
2. REST 移卡會觸發 `auto_start_agent`，**前提是卡帶 `agent_profile_id`**（沒帶則 `auto_start_failed`，卡停在 `SCHEDULING`）；從 UI 拖卡未驗證。
3. `reset_agent_context` 會隔離上下文（有正向對照：不重置的對照卡能回出祕密，重置的回 `NONE`）；無 session 的卡移入有 reset 的欄位不出錯。
4. `wip_limit` **不強制**，只把超額卡的 `wip_admitted` 標成 false；「同時只有一個 QA Run / Re-verify」要靠 prompt 規則（先 `list_tasks_kandev` 檢查）。

**仍未解決**：三張沒帶 `agent_profile_id` 的卡後來也有 session（來源不明）；UI 拖卡；相同 `external_id` 重複建卡的行為；`wip_admitted=false` 的實際作用。

**其餘開放問題**
5. **圖的查詢工具**：見 §5.5。
6. **後端合併後如何載入新碼**：Phase 1 的 BE 是容器內 `go run`（`dashboard-be-dev`），是否自動重載、是否要重建映像未驗證；Phase 2（混合式）完成後會簡化。實作計畫要先實測，並把結論寫進 `Merge-ready` 欄的 prompt。
7. **嚴重度與路由的邊界**：S2 是否一律進 `Decide`，跑過幾輪後再調整。

## 9. 實作範圍（交給下一份計畫）

- 擴充 `docs/agent-workflow/kandev_bootstrap.py`：目前所有 workflow 共用同一組 `COLUMNS`，要改成每條 workflow 自己的欄位；新增 `Q 品質迴圈` 與 §3 的欄位及 prompt；維持冪等，並更新 `test_kandev_bootstrap.py`（含 Q workflow 的欄位順序、`QA Run` 前置 `Backlog`、`Done` 的 `complete_task_on_enter`）。此檔為程式碼，走 worktree。
- 建立 `docs/qa/` 骨架與模板：`runs/`、`events/`、`digest/`、`evidence/` 與 BUG 卡模板。
- §8 的實測已在計畫 Task 1 完成；本計畫其餘任務解決開放問題 5、6。
- **端到端演練**：用一個刻意植入、可還原的小缺陷，從 `QA-RUN` 一路走到 `Done`，並強制一次複驗失敗以驗證退回與升級規則。驗收條件：每個欄位 session 只讀 `CLAUDE.md` 與卡；候選檔案包含真正需要改的檔案；產生事件檔與摘要檔；無祕密外洩；圖的新鮮度檢查會在不一致時提示。
- 驗收通過後，把狀態與里程碑更新到 `MEMORY.md`，並在 `CLAUDE.md` 的 Kandev 段落補上 Q workflow 一行。

## 10. 不做的事

不自動排程、不接外部通知通道、不做多 QA 並行、不為每個 worktree 各起一組服務、不讓 QA agent 修碼、不讓修復者驗自己的修復、不把知識圖當作判斷依據而不讀碼。
