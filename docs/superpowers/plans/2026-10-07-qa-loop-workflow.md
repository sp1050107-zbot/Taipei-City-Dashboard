# QA 品質迴圈 Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Kandev 建立第三條 workflow `Q 品質迴圈`（QA → bug → Fix → 複驗 → 摘要檔），手動觸發 QA，並用知識圖縮小分流與影響範圍。

**Architecture:** 先用拋棄式探測實測 Kandev 的三個機制（agent 開卡、欄位自動啟動、session 重置），再依結果建 `docs/qa/` 骨架、圖查詢工具與 Q workflow 的欄位定義（每欄有自己的 `on_enter` 動作與 prompt），最後套用到即時 Kandev 並用兩輪演練驗收。

**Tech Stack:** Python 3 標準庫（`kandev_bootstrap.py`、手寫測試腳本，不用 pytest）、Node.js ESM + vitest（圖查詢工具，放在 `~/Understand-Anything` fork）、bash（文件檢查）、Kandev REST 與 MCP。

**Spec:** `docs/superpowers/specs/2026-10-07-qa-loop-workflow-design.md`（含 §8 已查證結論）。執行者先讀 spec §3、§4、§8，再讀本計畫。

## Global Constraints

- 程式碼、腳本、設定：只在 worktree（`~/Taipei-City-Dashboard-worktrees/<name>`，分支 `feature/<slug>`）進行，通過後經使用者核准才本機 merge 回 `develop`（`AGENTS.md` 規則 1）。`docs/`、`.planning/`、`.ua/`、`CLAUDE.md`、`AGENTS.md`、`MEMORY.md` 可直接在整合 checkout commit（規則 2）。
- 不 `git push`、不對 upstream 發 PR（規則 3）。
- 祕密：`mapbox-key.txt`、`docker/.env` 永不 commit、永不印出；每次 commit 前用 token 完整字串比對 staged diff：`TOK=$(tr -d '[:space:]' < mapbox-key.txt); git diff --cached | grep -qF -- "$TOK" && echo LEAK || echo ok`（規則 4）。
- 新增的 `.sh` 要用 `git add -f`，因為上游 `.gitignore` 忽略 `*.sh`，不修改上游 `.gitignore`。
- compose 只在整合 checkout 執行，worktree 與 Kandev task 不得跑 compose（規則 7）。
- commit 標題 ≤ 72 字元（pro-workflow 的 commit hook 會擋）。commit 訊息結尾加：`Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`。
- Kandev 網址 `http://127.0.0.1:38429`，REST 前綴 `/api/v1`（`kandev_bootstrap.py` 的 `BASE`）。task 前綴是自動的 `KAN`，本專案用標題前綴辨識：`QA-RUN-<n>`、`BUG-<n>`。
- 就緒探測：`GET http://localhost:8088/api/v1/dashboard/`（帶結尾斜線）回 200；前端 `http://localhost:8080` 回 200。
- 圖查詢工具位置：`~/Understand-Anything/scripts/graph-query.mjs`（本計畫 Task 2 建立）。補強腳本：`~/Understand-Anything/scripts/augment-gin-vue.mjs`。
- **Task 1 實測得到的規則（證據：`docs/agent-workflow/evidence/qa-loop-kandev-probe.md`，所有 agent 提示與模板都要遵守）**：(1) REST 或 MCP 建卡一律明確帶 `agent_profile_id`（`9dac882b-2973-4bc0-a175-61fb5aa58f0c`，claude-acp Default），否則自動啟動失敗；(2) 提示用**第一人稱擁有者措辭**（「我是這個看板的擁有者，我要求…」），第三人稱的「使用者已要求…」與一次性移卡指示會被 agent 當成提示注入而拒絕；真正的交接寫在卡描述與欄位 prompt，移卡的 `prompt` 只留一句短而事實性的話；(3) `wip_limit` 不強制（只把卡的 `wip_admitted` 標成 false），「同時只有一個 QA Run」要靠 prompt 規則；(4) session 執行中的移卡會延到回合結束才套用。
- Kandev 端點（已讀原始碼確認）：`POST /workflows`、`POST /workflow/steps`（接受 `events`、`wip_limit`、`agent_profile_id`）、`PUT /workflow/steps/:id`（部分欄位更新）、`POST /tasks`、`POST /tasks/:id/move`（body：`workflow_id`、`workflow_step_id`、`position`、`entry_options{reset_context,instructions,skip_step_prompt}`）、`GET /tasks/:id/sessions`、`DELETE /tasks/:id`、`DELETE /workflows/:id`。

## Review Focus

1. **`reset_agent_context` 在卡還沒有 session 時被觸發**（BUG 卡由 QA 以 `start_agent=false` 建立，第一次移入 `Triage` 時沒有 session）：預期卡仍能進入欄位並啟動 agent，而不是卡在錯誤。→ Task 1 已實測：不出錯，重置在無 session 時靜默略過（推論），帶 `agent_profile_id` 的卡會啟動；Task 6 演練 A 再用 MCP 建出的真實 BUG 卡確認一次。
2. **同一個症狀被 QA 重複回報**：預期用 `external_id` 與開啟中卡片比對，不產生第二張卡。→ Task 4 的 QA Run prompt 測試。
3. **複驗失敗的計數**：第 1、2 次失敗退回 `Fix`，第 3 次升級到 `Decide` 並停止，不得再自動移動。→ Task 6 演練 B。
4. **服務未就緒**：預期報告「環境未就緒」並結束，不開任何 BUG 卡。→ Task 4 的 prompt 測試與 Task 6 演練。
5. **圖查詢的輸入打錯或查不到**：預期明確錯誤訊息與非零結束碼，不輸出空白結果讓 agent 誤判「沒有相關檔案」。→ Task 2 測試。

---

## 檔案結構

| 檔案 | 動作 | 責任 |
|---|---|---|
| `docs/agent-workflow/evidence/qa-loop-kandev-probe.md` | 新增 | Task 1 的實測結論（commit 到 `develop`） |
| `~/Understand-Anything/scripts/graph-query.mjs` | 新增（另一個 repo） | 圖查詢：`chain`（往下追）、`impact`（往上追） |
| `~/Understand-Anything/tests/scripts/graph-query.test.mjs` | 新增 | 圖查詢測試 |
| `docs/qa/README.md`、`docs/qa/templates/*.md`、`docs/qa/{runs,events,digest,evidence}/.gitkeep` | 新增 | QA 目錄骨架、嚴重度表、卡片與報告模板 |
| `docs/agent-workflow/check-qa-docs.sh` | 新增 | 驗證 `docs/qa/` 骨架與模板必要標頭 |
| `docs/agent-workflow/kandev_bootstrap.py` | 修改 | 加入 `Q_COLUMNS`、每個 workflow 自己的欄位、`events`/`wip_limit`、Q 欄位就地同步 |
| `docs/agent-workflow/test_kandev_bootstrap.py` | 修改 | 離線欄位形狀測試 + 即時 Kandev 驗證 Q workflow |
| `CLAUDE.md`、`MEMORY.md` | 修改 | 記錄 Q workflow（Task 7） |

---

### Task 1: 在即時 Kandev 實測三個機制（拋棄式探測）

> **已完成（2026-10-07）**：commits `715ef548`、`4d6fe275`、`40ad51bf`，結論 `DECISION: ON_ENTER = [reset_agent_context, auto_start_agent]`，證據見 `docs/agent-workflow/evidence/qa-loop-kandev-probe.md`。以下步驟保留作為紀錄與重跑依據。

這個任務**會寫入即時 Kandev 並消耗少量 `claude-acp` 額度**，開始前先請使用者確認。全部寫入都用 `ZZ-PROBE` 前綴，結束時一律刪除。不寫程式進 repo，只留證據文件。

**Files:**
- Create (scratchpad，不入 repo): `$SCRATCH/probe_q.py`（`$SCRATCH` = 本 session 的 scratchpad 目錄）
- Create: `docs/agent-workflow/evidence/qa-loop-kandev-probe.md`

**Interfaces:**
- Produces: 證據文件中的四個明確結論，Task 4 依此決定 `ON_ENTER`：
  - `RESET_ON_SESSIONLESS_ENTRY`: `ok` | `error`（`reset_agent_context` 在無 session 的卡移入時是否出錯）
  - `AUTO_START_VIA_UI_MOVE` / `AUTO_START_VIA_REST_MOVE`: `yes` | `no`
  - `RESET_ISOLATES_CONTEXT`: `yes` | `no`
  - `AGENT_CAN_CREATE_AND_MOVE`: `yes` | `no`（`create_task_kandev` 與 `move_task_kandev` 在 `claude-acp` session 內可呼叫）
  - `REST_CREATE_NEEDS_AGENT_PROFILE`: `yes` | `no`（2026-10-07 首次執行觀察到：REST 建卡不帶 `agent_profile_id` 時 `auto_start_failed`）
  - `CREATE_IN_AUTO_STEP_STARTS_AGENT`: `yes` | `no`（首次執行觀察到：直接在有 `auto_start_agent` 的欄位建卡沒有產生 session，移入才啟動——待 1a 確認）

**執行修訂（2026-10-07 首次執行後）**

首次執行（單一 agent 跑完整個 Task 1）約 17 分鐘後在途中中斷，且有三個設計問題。已知並修正如下，之後依 1a–1d 四段分別派工，每段目標 5 分鐘內完成、失敗影響範圍小：

1. 時間預估：Kandev 每次啟動 agent session 約 60–70 秒，6 個實驗光等待就 7 分鐘以上。不要用前景 `sleep`（超過 120 秒會被轉背景、`sleep 60` 會被 harness 擋下）；等待用 `timeout 100 python3 script.py`（腳本內 `time.sleep` ≤ 80 秒）或背景命令加 until-loop。
2. `mk_task` 必須帶 `"agent_profile_id": "9dac882b-2973-4bc0-a175-61fb5aa58f0c"`（下方 Step 2 程式碼已更正），否則卡 `auto_start_failed`。
3. Step 4 的隔離實驗設計有缺陷：祕密字寫在卡描述裡，而描述每次進欄位都會被當作 `{{task_prompt}}` 重送，所以回答 `STORED` 在隔離與不隔離兩種情況下都成立。已改為「祕密只放在一次性 `instructions`，並加一個正向對照」（下方 Step 4）。
4. 重用現有探測物件：`probe_state.json`（scratchpad）記錄了 workflow `b21dd736…`、欄位 `a`/`b`/`c` 與 6 張卡的 id；1a 直接檢視它們已產生的 session 與訊息，不重做。

分段對應：**1a** = Step 3 + 檢視既有結果（`RESET_ON_SESSIONLESS_ENTRY`、`AUTO_START_VIA_REST_MOVE`、`REST_CREATE_NEEDS_AGENT_PROFILE`、`CREATE_IN_AUTO_STEP_STARTS_AGENT`）；**1b** = Step 4（`RESET_ISOLATES_CONTEXT`）；**1c** = Step 6 + Step 7（`AGENT_CAN_CREATE_AND_MOVE`、`wip_limit`）；**1d** = Step 5（UI，可標 unverified）+ Step 8–10（清理、證據文件、commit）。各段把結論追加到 `$WS/task-1-findings.md`，1d 彙整成證據文件。

- [ ] **Step 1: 請使用者確認可以在即時 Kandev 建立並刪除 `ZZ-PROBE` 前綴的工作流與卡片**

說明：預估建立 1 個 workflow、3 個欄位、約 3 張卡，使用 `claude-acp` 約 3–5 次短 turn；全部事後 `DELETE`。使用者確認後才繼續。

- [ ] **Step 2: 建立探測腳本（放 scratchpad）**

```python
#!/usr/bin/env python3
"""Throwaway probe for the QA-loop spec. Creates ZZ-PROBE objects in live Kandev; every create is printed so cleanup is exact."""
import json, os, sys, time, urllib.request, urllib.error

BASE = os.environ.get("KANDEV_URL", "http://127.0.0.1:38429/api/v1")
WS = "6115d5c0-d1f2-4261-8719-833f75ae00d4"   # workspace taipei-city-dashboard
EXEC = "exec-local"


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return {"__error__": e.code, "body": e.read().decode()[:600]}


def mk_workflow():
    wf = call("POST", "/workflows", {"workspace_id": WS, "name": "ZZ-PROBE (delete me)", "description": "throwaway"})
    print("workflow", wf.get("id"))
    return wf["id"]


def mk_step(wf, name, pos, events, wip=None, prompt=""):
    body = {"workflow_id": wf, "name": name, "position": pos, "color": "bg-neutral-400", "prompt": prompt,
            "allow_manual_move": True, "is_start_step": pos == 0, "stage_type": "custom",
            "complete_task_on_enter": False, "events": events}
    if wip:
        body["wip_limit"] = wip
    s = call("POST", "/workflow/steps", body)
    print("step", name, s.get("id") or s)
    return s["id"]


def mk_task(wf, step, title, desc, repo):
    t = call("POST", "/tasks", {"workspace_id": WS, "workflow_id": wf, "workflow_step_id": step, "title": title,
                                "description": desc, "executor_id": EXEC,
                                "agent_profile_id": "9dac882b-2973-4bc0-a175-61fb5aa58f0c",
                                "repositories": [{"repository_id": repo, "base_branch": "develop"}]})
    print("task", title, t.get("id") or t)
    return t["id"]


def move(task, wf, step, **entry):
    body = {"workflow_id": wf, "workflow_step_id": step, "position": 0}
    if entry:
        body["entry_options"] = entry
    return call("POST", f"/tasks/{task}/move", body)


def sessions(task):
    r = call("GET", f"/tasks/{task}/sessions")
    return r.get("sessions", r)


def messages(session_id):
    r = call("GET", f"/agent-sessions/{session_id}/messages")
    return r


if __name__ == "__main__":
    print(__doc__)
```

- [ ] **Step 3: 探測 A —— 建卡時落在有 `auto_start_agent` 的欄位，是否自動啟動；從沒有 session 的卡用 REST 移入 `reset_agent_context + auto_start_agent` 欄位是否出錯**

在 Python REPL（`python3 -i $SCRATCH/probe_q.py`）依序執行：

```python
repo = [r for r in call("GET", f"/workspaces/{WS}/repositories")["repositories"] if r["local_path"].endswith("Taipei-City-Dashboard")][0]["id"]
wf = mk_workflow()
a = mk_step(wf, "probe-a (auto)", 0, {"on_enter": [{"type": "auto_start_agent"}]})
b = mk_step(wf, "probe-b (reset+auto)", 1, {"on_enter": [{"type": "reset_agent_context"}, {"type": "auto_start_agent"}]})
c = mk_step(wf, "probe-c (wip1)", 2, {}, wip=1)
# A1: 建在無動作的第 3 欄（c），沒有 session；再移入 b
t1 = mk_task(wf, c, "ZZ-PROBE sessionless", "Reply with exactly: PROBE-B-OK and then stop.", repo)
print("sessions before move:", len(sessions(t1)))
print(move(t1, wf, b))
time.sleep(40)
print("sessions after move:", sessions(t1))
```

記錄：移入時 REST 是否回錯誤、40 秒後是否有 session 並產生回覆（回覆含 `PROBE-B-OK`）。對應結論 `RESET_ON_SESSIONLESS_ENTRY` 與 `AUTO_START_VIA_REST_MOVE`。

- [ ] **Step 4: 探測 B —— `reset_agent_context` 是否隔離上下文（含正向對照）**

設計原則：卡描述**不含**祕密（描述每次進欄位都會重送）；祕密只放在某次移卡的一次性 `instructions`；另用一張不重置的對照卡證明這個實驗有能力偵測到洩漏。步驟（`b` = `reset_agent_context + auto_start_agent`，`a` = 只有 `auto_start_agent`，`c` = 無動作）：

```python
# 兩張卡都建在 c（無動作、無 session），描述只要求回 READY
tI = mk_task(wf, c, "ZZ-PROBE iso", "Reply with exactly: READY and stop. Do not use any file or shell tools.", repo)   # 受測卡
tC = mk_task(wf, c, "ZZ-PROBE ctrl", "Reply with exactly: READY and stop. Do not use any file or shell tools.", repo)  # 對照卡
SECRET = "Remember the secret word PINEAPPLE-7731. Reply with: STORED and stop."
ASK = "Without using any tool, what secret word were you asked to remember earlier in this conversation? If you cannot see one, reply exactly: NONE."
# 第一輪：兩張都移進 b，帶祕密（b 第一次進入，會建立新對話）
move(tI, wf, b, instructions=SECRET); move(tC, wf, b, instructions=SECRET)
time.sleep(80)                      # 兩個 session 並行啟動
# 兩張都回 c 待命（c 無動作），再各自詢問
move(tI, wf, c); move(tC, wf, c)
move(tI, wf, b, instructions=ASK)   # 受測：進入有 reset 的欄位
move(tC, wf, a, instructions=ASK)   # 對照：進入沒有 reset 的欄位
time.sleep(80)
for t in (tI, tC):
    for s_ in sessions(t): print(t, s_["id"], s_["state"]); show_msgs(s_["id"], 400)
```

判讀（四個結果都要記下）：
- 對照卡回 `PINEAPPLE-7731` → 實驗有效（沒有 reset 時對話會沿用）。**若對照卡回 NONE，實驗無效**，記為 inconclusive 並改用同一 session 內的第二輪移卡重做，不得下結論。
- 受測卡回 `NONE` 且時間軸出現 `Context reset — new conversation started` → `RESET_ISOLATES_CONTEXT=yes`。
- 受測卡回 `PINEAPPLE-7731` → `no`（停止，回報使用者，見 Step 9 的 `DECISION: STOP`）。

- [ ] **Step 5: 探測 C —— 從 UI 拖卡是否也觸發**

用瀏覽器在 Kandev 看板把 `ZZ-PROBE sessionless` 先拖回 `probe-c`，再拖到 `probe-a`，觀察是否啟動新回合。結論 `AUTO_START_VIA_UI_MOVE`。

- [ ] **Step 6: 探測 D —— agent 能否在 session 內呼叫 `create_task_kandev` 與 `move_task_kandev`**

```python
t3 = mk_task(wf, a, "ZZ-PROBE mcp", (
    "The user explicitly requests a Kandev tracked child task for this probe. "
    "1) Call list_workflow_steps_kandev for workflow %s. "
    "2) Call create_task_kandev with title 'ZZ-PROBE child', workflow_id %s, workflow_step_id %s, "
    "repository_id %s, executor_profile_id exec-local, start_agent=false, external_id 'ZZ-PROBE-1', prompt 'probe child'. "
    "3) Call move_task_kandev for THIS task to workflow_step_id %s (workflow_id %s) with prompt 'probe handoff'. "
    "4) Reply with the two task ids and stop." % (wf, wf, c, repo, c, wf)), repo)
time.sleep(90); print(sessions(t3))
print([t["title"] for t in call("GET", f"/workspaces/{WS}/tasks")["tasks"] if t["title"].startswith("ZZ-PROBE")])
```

`ZZ-PROBE child` 出現、`ZZ-PROBE mcp` 被移到 `probe-c` → `AGENT_CAN_CREATE_AND_MOVE=yes`。若被權限擋下或工具不存在，記下錯誤訊息原文。

- [ ] **Step 7: 探測 E —— `wip_limit`**

```python
t4 = mk_task(wf, c, "ZZ-PROBE wip-1", "idle", repo)
t5 = mk_task(wf, c, "ZZ-PROBE wip-2", "idle", repo)
print([ (t["title"], t.get("workflow_step_id") == c) for t in call("GET", f"/workspaces/{WS}/tasks")["tasks"] if t["title"].startswith("ZZ-PROBE wip")])
```

記錄第 2 張卡在 `wip_limit=1` 的欄位是被擋下、被警告、還是照樣建立。

- [ ] **Step 8: 清除所有 `ZZ-PROBE` 物件並確認**

```python
for t in call("GET", f"/workspaces/{WS}/tasks")["tasks"]:
    if t["title"].startswith("ZZ-PROBE"):
        print("delete task", t["title"], call("DELETE", f"/tasks/{t['id']}"))
print("delete workflow", call("DELETE", f"/workflows/{wf}"))
left = [t["title"] for t in call("GET", f"/workspaces/{WS}/tasks")["tasks"] if t["title"].startswith("ZZ-PROBE")]
left_wf = [w["name"] for w in call("GET", "/workflows")["workflows"] if w["name"].startswith("ZZ-PROBE")]
print("left tasks:", left, "left workflows:", left_wf)
```

Expected: 兩個 `left` 都是 `[]`。若有殘留，逐一 `DELETE` 後重查，直到清空。

- [ ] **Step 9: 寫證據文件**

建立 `docs/agent-workflow/evidence/qa-loop-kandev-probe.md`，標頭用既有格式（`目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`），並在「已決定」逐項填入 Step 3–7 的實測結果（五個結論變數與對應的原始輸出摘要，不含祕密）。結尾寫一行 `DECISION: ON_ENTER = [...]`，值依下表：

| 實測結果 | `ON_ENTER`（Task 4 使用） |
|---|---|
| `RESET_ON_SESSIONLESS_ENTRY=ok` 且 `RESET_ISOLATES_CONTEXT=yes` | `[reset_agent_context, auto_start_agent]` |
| `RESET_ON_SESSIONLESS_ENTRY=error` 且 `RESET_ISOLATES_CONTEXT=yes` | `[auto_start_agent]`，並要求 agent 移卡時一律帶 `entry_options.reset_context=true`（MCP 的 `prompt` 交接訊息仍要帶） |
| `RESET_ISOLATES_CONTEXT=no` | 停止，回報使用者：每欄一個乾淨 session 的假設不成立，改用「每欄各一張子卡」設計，需修改 spec |

- [ ] **Step 10: Commit 證據（文件類，直接在 develop）**

```bash
cd ~/Taipei-City-Dashboard
git add docs/agent-workflow/evidence/qa-loop-kandev-probe.md
TOK=$(tr -d '[:space:]' < mapbox-key.txt); git diff --cached | grep -qF -- "$TOK" && echo LEAK || echo ok
git commit -m "docs: record Kandev probe results for QA loop" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 圖查詢工具 `graph-query.mjs`（在 `~/Understand-Anything` fork）

> **已完成（2026-10-07）**：fork commits `8092737`（工具）與 `5169982`（`--depth` 驗證、路徑正規化、補測試）。下方程式碼為實際 commit 的版本，步驟保留作為紀錄。

解決 spec §5.5。放在 fork 而不是本 repo，因為它讀的是 Understand-Anything 的圖格式，且與 `augment-gin-vue.mjs` 同一處維護。

**Files:**
- Create: `~/Understand-Anything/scripts/graph-query.mjs`
- Test: `~/Understand-Anything/tests/scripts/graph-query.test.mjs`
- Modify: `~/Understand-Anything/CLAUDE.md`（Scripts 段落加一行）

**Interfaces:**
- Produces（CLI）:
  - `node graph-query.mjs <projectRoot> chain "<query>" [--depth N] [--json]` — 從 endpoint 名稱（如 `GET /api/v1/component/:id/chart`）或檔案路徑（子字串）往下追 `routes`/`calls`/`imports`/`middleware` 邊，預設深度 3。
  - `node graph-query.mjs <projectRoot> impact <path>... [--depth N] [--json]` — 從修改過的檔案往上追，列出受影響的 endpoint、檔案、測試（`tested_by`）。
  - 查不到起點：stderr 輸出原因與相近名稱，結束碼 2。
- Produces（匯出函式）: `loadGraph(projectRoot): Graph`、`findStart(graph, query): Node[]`、`nodesOfFile(graph, rel): Node[]`、`traverse(graph, starts, {depth, direction}): Map<id, depth>`、`summarize(graph, seen): {files:[{file,layer,depth,symbols,sameName}], endpoints:[string], tests:[string], totalEndpoints:number, broad:boolean}`、`printText(title, summary, all)`
- 圖的限制（已用真實圖驗證，工具必須誠實呈現）：Go 的 `imports` 邊是**套件層級**，一個 import 會拉進整個套件。所以 (a) 檔名與較近檔案相同的檔案（`controllers/componentData.go` ↔ `models/componentData.go`）標記 `sameName`，文字輸出優先顯示，其餘折疊成「+N more」；(b) `impact` 若觸及超過一半的 endpoint，標記 `broad` 並印出警告、不列出 endpoint 清單，要求 agent 改用 grep 縮小。前端 `.vue`/`.js` 的 import 是檔案層級，較精確。
- 遍歷規則：函式與其所在檔案以**同深度**相連（往下：函式 → 其檔案 → 該檔案的 imports；往上：檔案 → 其函式 → `routes`/`calls` 的反向），因為 `routes`/`calls` 邊只到函式，而後端依賴主要是檔案層級 `imports`。

- [ ] **Step 1: 寫失敗的測試**

```js
import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { findStart, traverse, summarize } from '../../scripts/graph-query.mjs';

const SCRIPT = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../scripts/graph-query.mjs');
const n = (id, type, extra = {}) => ({ id, type, name: extra.name ?? id.split(':').pop(), filePath: extra.filePath, summary: 's', tags: ['t'], complexity: 'simple' });

const graph = {
  nodes: [
    n('file:r/router.go', 'file', { filePath: 'r/router.go' }),
    n('endpoint:r/router.go:GET /api/v1/x', 'endpoint', { name: 'GET /api/v1/x', filePath: 'r/router.go' }),
    n('file:c/x.go', 'file', { filePath: 'c/x.go' }), n('function:c/x.go:GetX', 'function', { name: 'GetX', filePath: 'c/x.go' }),
    n('file:s/x.go', 'file', { filePath: 's/x.go' }), n('function:s/x.go:LoadX', 'function', { name: 'LoadX', filePath: 's/x.go' }),
    n('file:m/x.go', 'file', { filePath: 'm/x.go' }), n('function:m/x.go:FindX', 'function', { name: 'FindX', filePath: 'm/x.go' }),
    n('file:s/x_test.go', 'file', { filePath: 's/x_test.go' }),
  ],
  edges: [
    { source: 'endpoint:r/router.go:GET /api/v1/x', target: 'function:c/x.go:GetX', type: 'routes' },
    { source: 'function:c/x.go:GetX', target: 'function:s/x.go:LoadX', type: 'calls' },
    { source: 'function:s/x.go:LoadX', target: 'function:m/x.go:FindX', type: 'calls' },
    { source: 'file:s/x.go', target: 'file:s/x_test.go', type: 'tested_by' },
    { source: 'file:r/router.go', target: 'endpoint:r/router.go:GET /api/v1/x', type: 'contains' },
  ],
  layers: [{ id: 'layer:api', name: 'API', description: 'd', nodeIds: ['file:r/router.go', 'file:c/x.go'] },
           { id: 'layer:svc', name: 'Service', description: 'd', nodeIds: ['file:s/x.go', 'file:m/x.go', 'file:s/x_test.go'] }],
};

describe('graph-query', () => {
  it('finds an endpoint by exact name and a file by path substring', () => {
    expect(findStart(graph, 'GET /api/v1/x').map(x => x.id)).toEqual(['endpoint:r/router.go:GET /api/v1/x']);
    expect(findStart(graph, 'm/x.go').map(x => x.id)).toContain('file:m/x.go');
    expect(findStart(graph, 'nope/nothing')).toEqual([]);
  });

  it('chain follows routes/calls down to the requested depth', () => {
    const starts = findStart(graph, 'GET /api/v1/x');
    const d1 = summarize(graph, traverse(graph, starts, { depth: 1, direction: 'down' }));
    expect(d1.files.map(f => f.file)).toEqual(['c/x.go']);
    const d3 = summarize(graph, traverse(graph, starts, { depth: 3, direction: 'down' }));
    expect(d3.files.map(f => f.file).sort()).toEqual(['c/x.go', 'm/x.go', 's/x.go']);
    expect(d3.files.find(f => f.file === 'm/x.go').layer).toBe('Service');
  });

  it('impact walks up from a changed file to endpoints and its tests', () => {
    const starts = [graph.nodes.find(x => x.id === 'file:m/x.go'), graph.nodes.find(x => x.id === 'function:m/x.go:FindX')];
    const s = summarize(graph, traverse(graph, starts, { depth: 4, direction: 'up' }));
    expect(s.endpoints).toEqual(['GET /api/v1/x']);
    expect(s.files.map(f => f.file)).toContain('c/x.go');
    const fromService = summarize(graph, traverse(graph, [graph.nodes.find(x => x.id === 'file:s/x.go'), graph.nodes.find(x => x.id === 'function:s/x.go:LoadX')], { depth: 2, direction: 'up' }));
    expect(fromService.tests).toEqual(['s/x_test.go']);
  });

  it('a symbol and its file are linked at the same depth, so file-level imports are followed', () => {
    const g = {
      nodes: [n('endpoint:r.go:GET /h', 'endpoint', { name: 'GET /h', filePath: 'r.go' }), n('function:h/h.go:Handle', 'function', { name: 'Handle', filePath: 'h/h.go' }),
        n('file:h/h.go', 'file', { filePath: 'h/h.go' }), n('file:u/u.go', 'file', { filePath: 'u/u.go' }), n('file:m/h.go', 'file', { filePath: 'm/h.go' })],
      edges: [{ source: 'endpoint:r.go:GET /h', target: 'function:h/h.go:Handle', type: 'routes' },
        { source: 'file:h/h.go', target: 'file:u/u.go', type: 'imports' }, { source: 'file:h/h.go', target: 'file:m/h.go', type: 'imports' }],
      layers: [],
    };
    const down = summarize(g, traverse(g, findStart(g, 'GET /h'), { depth: 2, direction: 'down' }));
    expect(down.files.map(f => f.file)).toEqual(['h/h.go', 'm/h.go', 'u/u.go']);
    expect(down.files.find(f => f.file === 'm/h.go').sameName).toBe(true);   // same basename as nearer h/h.go
    expect(down.files.find(f => f.file === 'u/u.go').sameName).toBe(false);
    const up = summarize(g, traverse(g, [g.nodes.find(x => x.id === 'file:u/u.go')], { depth: 3, direction: 'up' }));
    expect(up.endpoints).toEqual(['GET /h']);
  });

  it('flags an impact result that reaches most endpoints as broad', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ua-gq-broad-'));
    fs.mkdirSync(path.join(dir, '.ua'));
    fs.writeFileSync(path.join(dir, '.ua/knowledge-graph.json'), JSON.stringify(graph));
    const out = JSON.parse(execFileSync('node', [SCRIPT, dir, 'impact', 'm/x.go', '--json'], { encoding: 'utf8' }));
    expect(out.broad).toBe(true);          // 1 of 1 endpoints
    expect(out.totalEndpoints).toBe(1);
    const text = execFileSync('node', [SCRIPT, dir, 'impact', 'm/x.go'], { encoding: 'utf8' });
    expect(text).toMatch(/BROAD/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('CLI exits 2 with a clear message when nothing matches', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ua-gq-'));
    fs.mkdirSync(path.join(dir, '.ua'));
    fs.writeFileSync(path.join(dir, '.ua/knowledge-graph.json'), JSON.stringify(graph));
    const r = spawnSync('node', [SCRIPT, dir, 'chain', 'does/not/exist'], { encoding: 'utf8' });
    expect(r.status).toBe(2);
    expect(r.stderr).toMatch(/no node matches/i);
    const ok = execFileSync('node', [SCRIPT, dir, 'chain', 'GET /api/v1/x', '--json'], { encoding: 'utf8' });
    expect(JSON.parse(ok).files.map(f => f.file)).toContain('c/x.go');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  // --- honesty / input-handling behaviours ---
  const withGraph = (g, fn) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ua-gq-x-'));
    fs.mkdirSync(path.join(dir, '.ua'));
    fs.writeFileSync(path.join(dir, '.ua/knowledge-graph.json'), JSON.stringify(g));
    try { return fn(dir); } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  };
  const run = (...a) => spawnSync('node', [SCRIPT, ...a], { encoding: 'utf8' });

  it('does not flag impact as broad when it reaches only some endpoints, and lists them', () => {
    const g = {
      nodes: [
        n('endpoint:r.go:GET /a', 'endpoint', { name: 'GET /a', filePath: 'r.go' }), n('endpoint:r.go:GET /b', 'endpoint', { name: 'GET /b', filePath: 'r.go' }),
        n('function:a/a.go:A', 'function', { name: 'A', filePath: 'a/a.go' }), n('file:a/a.go', 'file', { filePath: 'a/a.go' }),
        n('function:b/b.go:B', 'function', { name: 'B', filePath: 'b/b.go' }), n('file:b/b.go', 'file', { filePath: 'b/b.go' }),
      ],
      edges: [{ source: 'endpoint:r.go:GET /a', target: 'function:a/a.go:A', type: 'routes' }, { source: 'endpoint:r.go:GET /b', target: 'function:b/b.go:B', type: 'routes' }],
      layers: [],
    };
    withGraph(g, dir => {
      const out = JSON.parse(run(dir, 'impact', 'a/a.go', '--json').stdout);
      expect(out.broad).toBe(false);
      expect(out.totalEndpoints).toBe(2);
      expect(out.endpoints).toEqual(['GET /a']);
      const text = run(dir, 'impact', 'a/a.go').stdout;
      expect(text).not.toMatch(/BROAD/);
      expect(text).toContain('GET /a');
      expect(text).not.toContain('GET /b');
    });
  });

  it('validates --depth: bad or missing values exit 1 with usage; a valid value keeps the query intact', () => {
    withGraph(graph, dir => {
      for (const bad of [['--depth', 'abc'], ['--depth', '0'], ['--depth', '-2'], ['--depth', '1.5']]) {
        const r = run(dir, 'chain', 'GET /api/v1/x', ...bad);
        expect(r.status, bad.join(' ')).toBe(1);
        expect(r.stderr).toMatch(/usage/i);
      }
      const last = run(dir, 'chain', 'GET /api/v1/x', '--depth');
      expect(last.status).toBe(1);
      expect(last.stderr).toMatch(/usage/i);
      const ok = run(dir, 'chain', 'GET /api/v1/x', '--depth', '2', '--json');
      expect(ok.status).toBe(0);
      expect(JSON.parse(ok.stdout).files.map(f => f.file)).toEqual(['c/x.go', 's/x.go']);
      // flag before the query and a depth value equal to a positional must not eat the wrong argument
      const early = run('--depth', '2', dir, 'chain', 'GET /api/v1/x', '--json');
      expect(JSON.parse(early.stdout).files.map(f => f.file)).toEqual(['c/x.go', 's/x.go']);
    });
  });

  it('impact normalises ./relative and absolute paths against the project root', () => {
    withGraph(graph, dir => {
      const files = (...a) => JSON.parse(run(dir, 'impact', ...a, '--json').stdout).files.map(f => f.file);
      const base = files('m/x.go');
      expect(base).toContain('c/x.go');
      expect(files('./m/x.go')).toEqual(base);
      expect(files(path.join(dir, 'm/x.go'))).toEqual(base);
      const miss = run(dir, 'impact', '/definitely/outside/y.go');
      expect(miss.status).toBe(2);
      expect(miss.stderr).toContain('/definitely/outside/y.go');
    });
  });

  it('collapses symbol-less deeper files into a "more" line and --all lists them', () => {
    const g = {
      nodes: ['a/a.go', 'b/b.go', 'c/c.go', 'd/d.go'].map(f => n(`file:${f}`, 'file', { filePath: f })),
      edges: [{ source: 'file:a/a.go', target: 'file:b/b.go', type: 'imports' }, { source: 'file:b/b.go', target: 'file:c/c.go', type: 'imports' }, { source: 'file:b/b.go', target: 'file:d/d.go', type: 'imports' }],
      layers: [],
    };
    withGraph(g, dir => {
      const text = run(dir, 'chain', 'a/a.go', '--depth', '2').stdout;
      expect(text).toContain('b/b.go');
      expect(text).toMatch(/\+2 more \(package-level imports\)/);
      expect(text).not.toContain('c/c.go  [');
      const all = run(dir, 'chain', 'a/a.go', '--depth', '2', '--all').stdout;
      expect(all).toContain('c/c.go');
      expect(all).toContain('d/d.go');
      expect(all).not.toMatch(/more \(package-level imports\)/);
    });
  });
});
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd ~/Understand-Anything && npx vitest run tests/scripts/graph-query.test.mjs`
Expected: FAIL（找不到 `scripts/graph-query.mjs`）

- [ ] **Step 3: 實作**

```js
#!/usr/bin/env node
// Query an Understand-Anything knowledge graph for AI task routing.
//   chain  <query>   follow routes/calls/imports/middleware edges DOWN from an endpoint or file
//   impact <path>... follow the same edges UP from changed files (endpoints, files, tests)
// Usage: node scripts/graph-query.mjs <projectRoot> chain "<query>" [--depth N] [--json]
//        node scripts/graph-query.mjs <projectRoot> impact <path>... [--depth N] [--json]
// Not part of the production pipeline. The graph is a hint: always confirm by reading code.
import fs from 'node:fs';
import path from 'node:path';

const EDGE_TYPES = new Set(['routes', 'calls', 'imports', 'middleware']);
const HTTP = /^(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD|ANY)\s/i;

export function loadGraph(projectRoot) {
  const legacy = path.join(projectRoot, '.understand-anything');
  const dir = fs.existsSync(legacy) ? legacy : path.join(projectRoot, '.ua');
  return JSON.parse(fs.readFileSync(path.join(dir, 'knowledge-graph.json'), 'utf8'));
}

export function findStart(graph, query) {
  const q = query.toLowerCase();
  const exact = graph.nodes.filter(n => n.id.toLowerCase() === q || n.name?.toLowerCase() === q);
  if (exact.length) return exact;
  if (HTTP.test(query)) return graph.nodes.filter(n => n.type === 'endpoint' && n.name.toLowerCase().includes(q));
  return graph.nodes.filter(n => n.type === 'file' && (n.filePath ?? '').toLowerCase().includes(q));
}

export function nodesOfFile(graph, rel) {
  return graph.nodes.filter(n => n.filePath === rel && n.type !== 'endpoint');
}

export function traverse(graph, starts, { depth = 3, direction = 'down' } = {}) {
  const adj = new Map();
  for (const e of graph.edges) {
    if (!EDGE_TYPES.has(e.type)) continue;
    const [from, to] = direction === 'down' ? [e.source, e.target] : [e.target, e.source];
    if (!adj.has(from)) adj.set(from, []);
    adj.get(from).push(to);
  }
  // Backend dependencies are mostly file-level `imports`, while `routes`/`calls` end at functions. So a symbol and its
  // file are linked at the same depth: going down a function also reaches its file (and that file's imports); going up
  // a file also reaches its functions (and whatever routes/calls them).
  const ids = new Set(graph.nodes.map(n => n.id));
  const link = new Map();
  for (const n of graph.nodes) {
    if (!n.filePath || n.type === 'file' || n.type === 'endpoint' || !ids.has(`file:${n.filePath}`)) continue;
    const f = `file:${n.filePath}`;
    const [from, to] = direction === 'down' ? [n.id, f] : [f, n.id];
    if (!link.has(from)) link.set(from, []);
    link.get(from).push(to);
  }
  const seen = new Map();
  let next = [];
  const add = (id, d) => {
    if (seen.has(id)) return;
    seen.set(id, d);
    next.push(id);
    for (const l of link.get(id) ?? []) add(l, d);
  };
  for (const s of starts) add(s.id, 0);
  for (let d = 1; d <= depth; d++) {
    const frontier = next;
    next = [];
    for (const id of frontier) for (const to of adj.get(id) ?? []) add(to, d);
  }
  return seen;
}

export function summarize(graph, seen) {
  const byId = new Map(graph.nodes.map(n => [n.id, n]));
  const layerOf = new Map();
  for (const l of graph.layers ?? []) for (const id of l.nodeIds) layerOf.set(id, l.name);
  const files = new Map();
  const endpoints = [];
  for (const [id, depth] of seen) {
    const node = byId.get(id);
    if (!node) continue;
    if (node.type === 'endpoint') { endpoints.push(node.name); continue; }
    if (!node.filePath || depth === 0) continue;
    const rec = files.get(node.filePath) ?? { file: node.filePath, layer: layerOf.get(`file:${node.filePath}`) ?? null, depth, symbols: [] };
    rec.depth = Math.min(rec.depth, depth);
    if (node.type !== 'file') rec.symbols.push(node.name);
    files.set(node.filePath, rec);
  }
  const visitedFiles = new Set([...seen.keys()].map(id => byId.get(id)?.filePath).filter(Boolean));
  const tests = graph.edges.filter(e => e.type === 'tested_by' && visitedFiles.has(byId.get(e.source)?.filePath))
    .map(e => byId.get(e.target)?.filePath).filter(Boolean);
  const list = [...files.values()].sort((a, b) => a.depth - b.depth || a.file.localeCompare(b.file));
  // Go imports are package-level, so one import pulls in a whole package. A file whose name matches a nearer file
  // (controllers/componentData.go -> models/componentData.go) is the likely real dependency: flag it.
  for (const f of list) f.sameName = list.some(o => o.depth < f.depth && path.basename(o.file) === path.basename(f.file));
  const totalEndpoints = graph.nodes.filter(n => n.type === 'endpoint').length;
  return { files: list, endpoints: endpoints.sort(), tests: [...new Set(tests)].sort(), totalEndpoints, broad: totalEndpoints > 0 && endpoints.length > totalEndpoints / 2 };
}

export function printText(title, s, all = false) {
  console.log(`# ${title}`);
  if (s.broad) {
    console.log(`WARNING: BROAD - reaches ${s.endpoints.length} of ${s.totalEndpoints} endpoints. Go imports are package-level, so this over-approximates; narrow it by grepping the changed function names in the backend instead of trusting this list.`);
  } else if (s.endpoints.length) console.log(`endpoints: ${s.endpoints.join(' | ')}`);
  console.log('depth  file  [layer]  symbols');
  const shown = s.files.filter(f => all || f.depth <= 1 || f.sameName || f.symbols.length);
  for (const f of shown) console.log(`${f.depth}  ${f.file}  [${f.layer ?? '-'}]  ${f.symbols.join(', ')}${f.sameName ? '  (same name as a nearer file)' : ''}`);
  const rest = s.files.filter(f => !shown.includes(f));
  if (rest.length) {
    const dirs = {};
    for (const f of rest) dirs[path.dirname(f.file)] = (dirs[path.dirname(f.file)] || 0) + 1;
    console.log(`+${rest.length} more (package-level imports): ${Object.entries(dirs).map(([d, c]) => `${d} (${c})`).join(', ')}; use --all to list`);
  }
  if (s.tests.length) console.log(`tests: ${s.tests.join(', ')}`);
  console.log('note: graph is a hint (.vue files have no function-level data); confirm by reading code.');
}

function main() {
  const args = process.argv.slice(2);
  const usage = 'usage: graph-query.mjs <projectRoot> chain "<query>" | impact <path>... [--depth N] [--json]';
  const flags = args.filter(a => a.startsWith('--'));
  const depthIdx = args.indexOf('--depth');
  let depth = 3;
  if (depthIdx >= 0) {
    const value = args[depthIdx + 1];
    depth = Number(value);
    if (value === undefined || value.trim() === '' || !Number.isInteger(depth) || depth < 1) {
      console.error(usage);
      process.exit(1);
    }
  }
  const pos = args.filter((a, i) => !a.startsWith('--') && !(depthIdx >= 0 && i === depthIdx + 1));
  const [root, cmd, ...rest] = pos;
  if (!root || !['chain', 'impact'].includes(cmd) || !rest.length) {
    console.error(usage);
    process.exit(1);
  }
  const projectRoot = path.resolve(root);
  const graph = loadGraph(projectRoot);
  // impact paths may be ./relative or absolute; match them as project-relative. Outside the project: keep as typed.
  const normalise = p => {
    const rel = path.relative(projectRoot, path.resolve(projectRoot, p));
    return rel.startsWith('..') ? p : rel;
  };
  const targets = cmd === 'impact' ? rest.map(normalise) : rest;
  let starts;
  if (cmd === 'chain') starts = findStart(graph, rest.join(' '));
  else starts = targets.flatMap(p => [...nodesOfFile(graph, p), ...graph.nodes.filter(n => n.id === `file:${p}`)]);
  if (!starts.length) {
    const hint = graph.nodes.filter(n => n.type === 'file' && n.filePath?.toLowerCase().includes(path.basename(targets[0]).toLowerCase())).slice(0, 5).map(n => n.filePath);
    console.error(`No node matches "${rest.join(' ')}".` + (hint.length ? ` Similar files: ${hint.join(', ')}` : ''));
    process.exit(2);
  }
  const seen = traverse(graph, starts, { depth, direction: cmd === 'chain' ? 'down' : 'up' });
  const s = summarize(graph, seen);
  if (flags.includes('--json')) console.log(JSON.stringify(s));
  else printText(`${cmd} ${rest.join(' ')} (depth ${depth})`, s, flags.includes('--all'));
}

if (import.meta.url === `file://${process.argv[1]}`) main();
```

- [ ] **Step 4: 執行測試確認通過**

Run: `cd ~/Understand-Anything && npx vitest run tests/scripts/graph-query.test.mjs && npx eslint scripts/graph-query.mjs tests/scripts/graph-query.test.mjs`
Expected: 10 個測試 PASS，ESLint 無輸出。（2026-10-07 執行後依審查加入 `--depth` 驗證、`impact` 路徑正規化與四個行為測試；程式碼為實際 commit `8092737`＋`5169982` 的版本。）

- [ ] **Step 5: 在真實圖上驗證**

```bash
cd ~/Understand-Anything
node scripts/graph-query.mjs ~/Taipei-City-Dashboard chain "GET /api/v1/component/:id/chart" --depth 3
node scripts/graph-query.mjs ~/Taipei-City-Dashboard chain "src/views/DashboardView.vue" --depth 2
node scripts/graph-query.mjs ~/Taipei-City-Dashboard impact Taipei-City-Dashboard-BE/app/models/componentData.go --depth 3
node scripts/graph-query.mjs ~/Taipei-City-Dashboard chain "no/such/file"; echo "exit=$?"
```

Expected（2026-10-07 在真實圖上實測的結果，圖更新後細節會變）：
- 第 1 個：深度 1 列出 `controllers/componentData.go`（符號 `GetComponentChartData`）與兩個中介層檔；深度 2 標出 `models/componentData.go` 為「same name as a nearer file」，其餘折疊成 `+N more (package-level imports)`。
- 第 2 個：列出 `DashboardView.vue` 直接 import 的 7 個檔案（與原始碼的 7 個 import 一致）。
- 第 3 個：印出 `WARNING: BROAD`（40 個 endpoint 中超過一半），不列 endpoint 清單。
- 第 4 個：印出 `No node matches` 且 `exit=2`。

若第 1 個沒有包含實際處理該路由的 controller，或第 2 個的 import 數與 `grep -c "^import" Taipei-City-Dashboard-FE/src/views/DashboardView.vue` 不符，停止並修正遍歷邏輯。

- [ ] **Step 6: 補 CLAUDE.md 與 commit（fork，兩個 commit 不需拆）**

在 `~/Understand-Anything/CLAUDE.md` 的 `scripts/augment-gin-vue.mjs` 那行之後新增一行：

```
- `scripts/graph-query.mjs` — Queries a knowledge graph for AI task routing: `chain "<endpoint or file>"` follows routes/calls/imports/middleware edges down, `impact <path>...` follows them up and lists affected endpoints, files and tests. Exits 2 when nothing matches. Go imports are package-level, so backend results over-approximate (flagged `BROAD`; same-name files are highlighted). The graph is a hint, not truth. Usage: `node scripts/graph-query.mjs <projectRoot> chain|impact ... [--depth N] [--json]`. Tests: `tests/scripts/`.
```

```bash
cd ~/Understand-Anything
git add scripts/graph-query.mjs tests/scripts/graph-query.test.mjs CLAUDE.md
git commit -m "feat(scripts): add graph-query for chain and impact lookups" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `docs/qa/` 骨架、模板與檢查腳本

**Files:**
- Create: `docs/agent-workflow/check-qa-docs.sh`
- Create: `docs/qa/README.md`
- Create: `docs/qa/templates/bug-card.md`、`qa-run-card.md`、`qa-run-report.md`、`event.md`、`digest.md`
- Create: `docs/qa/runs/.gitkeep`、`docs/qa/events/.gitkeep`、`docs/qa/digest/.gitkeep`、`docs/qa/evidence/.gitkeep`

**Interfaces:**
- Produces: `bug-card.md` 的欄位名（Task 4 的 prompt 會逐字引用）：`嚴重度`、`所屬層`、`重現步驟`、`預期 / 實際`、`證據`、`候選檔案`、`影響範圍`、`退回次數`。事件檔命名 `docs/qa/events/<YYYYMMDD-HHMM>-<編號>-<事件>.md`，事件值：`found`、`triaged`、`escalated`、`fixed-merged`、`verified-pass`、`verified-fail`、`closed`、`graph-stale`、`env-not-ready`。

（此任務為文件類，可直接在整合 checkout commit；檢查腳本是程式碼，連同骨架一起走 worktree 最單純：`git worktree add ~/Taipei-City-Dashboard-worktrees/qa-docs -b feature/qa-docs develop`。）

- [ ] **Step 1: 寫失敗的檢查腳本**

建立 `docs/agent-workflow/check-qa-docs.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

[ -f docs/qa/README.md ] || fail "docs/qa/README.md missing"
for d in runs events digest evidence templates; do [ -d "docs/qa/$d" ] || fail "docs/qa/$d missing"; done
for f in bug-card qa-run-card qa-run-report event digest; do
  [ -f "docs/qa/templates/$f.md" ] || fail "template $f.md missing"
done
for h in '目標' '已決定' '未決定' '下一步' '關鍵檔案路徑' '嚴重度' '所屬層' '重現步驟' '預期 / 實際' '證據' '候選檔案' '影響範圍' '退回次數'; do
  grep -q "$h" docs/qa/templates/bug-card.md || fail "bug-card.md lacks: $h"
done
for s in S1 S2 S3 S4; do grep -q "$s" docs/qa/README.md || fail "README lacks severity $s"; done
for h in '責任歸屬' 'env-not-ready' 'ESCALATED' '待你確認的 Closed' '20 分鐘'; do
  grep -q "$h" docs/qa/README.md || fail "README lacks ownership item: $h"
done
for h in '今日巡檢範圍與結果' '新增 bug' '已修並複驗通過' '退回中' '需要你決定' '待你確認的 Closed' '疑似停滯的卡' '知識圖是否過期'; do
  grep -q "$h" docs/qa/templates/digest.md || fail "digest.md lacks section: $h"
done
for e in found triaged escalated fixed-merged verified-pass verified-fail closed graph-stale env-not-ready; do
  grep -q "$e" docs/qa/templates/event.md || fail "event.md lacks event kind: $e"
done
if grep -rnE 'pk\.[A-Za-z0-9._-]{20,}|sk-[A-Za-z0-9]{20,}' docs/qa >/dev/null; then fail "possible secret in docs/qa"; fi
echo PASS
```

- [ ] **Step 2: 執行確認失敗**

Run: `bash docs/agent-workflow/check-qa-docs.sh`
Expected: `FAIL: docs/qa/README.md missing`

- [ ] **Step 3: 建立 README 與模板**

`docs/qa/README.md`：

```markdown
# docs/qa — QA 品質迴圈的紀錄

流程與規則見 `docs/superpowers/specs/2026-10-07-qa-loop-workflow-design.md`。本目錄只放產出。

| 目錄 | 內容 | 誰寫 |
|---|---|---|
| `runs/` | 每次巡檢的報告 `QA-RUN-<n>.md` | QA Run 欄的 agent |
| `events/` | 一事件一檔 `<YYYYMMDD-HHMM>-<編號>-<事件>.md` | 各欄位 agent |
| `digest/` | 當日摘要 `<YYYY-MM-DD>.md` | 單一 session 彙整（QA Run 結束或使用者要求） |
| `evidence/` | 證據 `BUG-<n>/`（截圖、curl 輸出，不含祕密） | QA agent |
| `templates/` | 卡片、報告、事件、摘要模板 | — |

## 嚴重度

| 級別 | 定義 | 例 |
|---|---|---|
| S1 | 核心功能完全不可用或資料毀損 | 登入失敗、儀表板整頁空白、BE 啟動崩潰 |
| S2 | 主要功能錯誤但有繞路 | 單一圖表資料錯誤、管理後台某操作失敗 |
| S3 | 次要功能或邊界情況錯誤 | 篩選條件在特定組合失效 |
| S4 | 外觀、文字、非功能性問題 | 錯字、對齊 |

路由：S3/S4 且候選檔案落在單一層 → 直接 `Fix`；S1/S2 或跨層 → 先 `Decide`。

## 責任歸屬（迴圈產出的問題由誰處理）

| 迴圈產出的情況 | 誰處理 | 說明 |
|---|---|---|
| 一般 bug（S3/S4、單一層） | Triage → Fix → Re-verify 各欄 agent | 你在 `Merge-ready` 核准合併 |
| S1/S2 或跨層 bug | 同上，另加 `Decide` agent | 合併一樣由你核准 |
| 複驗連續失敗（`ESCALATED`） | **你** | agent 在 `Decide` 停手，不再移動卡 |
| 服務未就緒（`env-not-ready`） | **你** | compose 只能在整合 checkout 跑，Kandev 任務不得跑 compose（`AGENTS.md` 規則 7），agent 無法重啟服務 |
| 知識圖過期（`graph-stale`） | **你** | 執行 `/understand` 增量更新與 `augment-gin-vue.mjs` |
| 卡片停滯 | **你** | 摘要檔列出「在自動啟動欄位超過 20 分鐘沒有 session 活動的卡」，你決定喚醒或停止 |
| `Closed`（重複、不修、無法重現） | Triage agent 判定，**你複核** | 摘要檔列出「待你確認的 Closed」與原因，你可把卡移回 `Reported` |
| 上游、資料來源、外部帳號類問題 | **你** | agent 只標 `Closed` 並寫原因；是否向上游回報由你決定（`AGENTS.md` 規則 3 預設不發 PR） |

原則：agent 能獨立完成且可逆的事由 agent 做；會改變共享狀態或不可逆的事（合併、重啟服務、對外回報、關閉卡的最終確認）由你做。

## 迴圈規則

- 複驗失敗退回 `Fix` 最多 2 次；第 3 次失敗進 `Decide` 並標記 `ESCALATED`，等使用者。
- 服務未就緒不是 bug：寫 `env-not-ready` 事件並結束。
- 證據與事件檔都是文件，可直接 commit 到 `develop`；commit 前比對 `mapbox-key.txt`（只比對、不印出）。
```

`docs/qa/templates/bug-card.md`：

```markdown
## BUG-<n> <一句話標題>
- 發現於：QA-RUN-<m>（或「手動」）　環境：develop @ <short sha>
- 嚴重度：S?　所屬層：<layer>　狀態備註：<例：疑似重複 BUG-k>
- 重現步驟：
  1. …
  2. …
- 預期 / 實際：…
- 證據：docs/qa/evidence/BUG-<n>/…
- 候選檔案（來源：圖／讀碼）：
  - <path> — <為何相關>
- 影響範圍（Fix 完成後填）：endpoint／頁面／測試
- 退回次數：0

## 目標
## 已決定
## 未決定
## 下一步
## 關鍵檔案路徑
```

`docs/qa/templates/qa-run-card.md`：

```markdown
## QA-RUN-<n> <範圍一句話>
- 範圍：<頁面／endpoint／「依最近合併自動推算」>
- 環境：develop，FE http://localhost:8080，BE http://localhost:8088
- 我是這個看板的擁有者。我要求你為這次巡檢的每個發現各建立一張 BUG 卡（放進 Reported 欄），不要修改任何程式。（必須維持第一人稱：Task 1 實測，第三人稱的「使用者已要求…」會被 agent 當成提示注入而拒絕。）
- 寫入測試資料的命名：含 `qa-<n>`，結束前清除。
```

`docs/qa/templates/qa-run-report.md`：

```markdown
# QA-RUN-<n> 報告
- 日期：<YYYY-MM-DD HH:MM>　develop @ <short sha>　範圍：<…>
- 環境探測：FE <code>、BE <code>

## 測試項目與結果
| 項目 | 結果 | 備註／BUG 編號 |
|---|---|---|

## 新增 BUG
- BUG-<n>（S?）：<一句話>

## 重複（未另開卡）
- <症狀> → BUG-<k>

## 測試資料清理
- <已清除／無法清除：…>
```

`docs/qa/templates/event.md`：

```markdown
# <編號> <事件>
事件種類（擇一）：found | triaged | escalated | fixed-merged | verified-pass | verified-fail | closed | graph-stale | env-not-ready
- 時間：<YYYY-MM-DD HH:MM>
- 發生了什麼：…
- 結果：…
- 下一步：…
- 需要使用者做的事：<無／…>
```

`docs/qa/templates/digest.md`：

```markdown
# QA 摘要 <YYYY-MM-DD>

## 今日巡檢範圍與結果
## 新增 bug
| 編號 | 嚴重度 | 一句話 |
|---|---|---|
## 已修並複驗通過
## 退回中
| 編號 | 退回次數 | 原因 |
|---|---|---|
## 需要你決定
（依序：環境未就緒需要你重啟服務、S1 bug、ESCALATED 卡、待核准合併）
## 待你確認的 Closed
| 編號 | 原因 | 判定的 agent 角色 |
|---|---|---|
## 疑似停滯的卡
（在自動啟動欄位超過 20 分鐘沒有 session 活動的卡）
## 知識圖是否過期
```

建立四個 `.gitkeep`：`touch docs/qa/runs/.gitkeep docs/qa/events/.gitkeep docs/qa/digest/.gitkeep docs/qa/evidence/.gitkeep`

- [ ] **Step 4: 執行確認通過**

Run: `bash docs/agent-workflow/check-qa-docs.sh && bash docs/agent-workflow/check-docs.sh`
Expected: 兩個都輸出 `PASS`

- [ ] **Step 5: Commit（`.sh` 要 `-f`）**

```bash
git add docs/qa
git add -f docs/agent-workflow/check-qa-docs.sh
TOK=$(tr -d '[:space:]' < mapbox-key.txt); git diff --cached | grep -qF -- "$TOK" && echo LEAK || echo ok
git commit -m "docs: add docs/qa skeleton, templates and check script" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Q workflow 欄位定義（`kandev_bootstrap.py`）

**Files:**
- Modify: `docs/agent-workflow/kandev_bootstrap.py`（`COLUMNS` 之後新增 `Q_COLUMNS`；改 `ensure_steps`、`main`）
- Modify: `docs/agent-workflow/test_kandev_bootstrap.py`

**Interfaces:**
- Consumes: Task 1 的 `DECISION: ON_ENTER`、Task 2 的 `graph-query.mjs` CLI、Task 3 的模板路徑與欄位名。
- Produces:
  - `Q_NAME = "Q 品質迴圈"`、`Q_COLUMNS: list[dict]`（每個含 `name,color,prompt`，可含 `events`、`wip_limit`、`done`）
  - `WORKFLOW_COLUMNS: dict[str, list]`（`A`、`B` 用 `COLUMNS`，Q 用 `Q_COLUMNS`）、`WORKFLOW_DESCS: dict[str, str]`
  - `ensure_steps(wf_id, columns=COLUMNS, sync=False) -> dict[name, step]`；`sync=True` 時對已存在欄位用 `PUT /workflow/steps/:id` 更新 `prompt`、`events`、`wip_limit`

Task 1 已完成，結論為 `ON_ENTER = [reset_agent_context, auto_start_agent]`，下列程式碼即依此；`HANDOFF` 註解的備案不需要。另依 Task 1 的規則：prompt 用第一人稱擁有者措辭、移卡 `prompt` 只留短句、建卡明確帶 `agent_profile_id`、一次只跑一個 QA Run 用 prompt 規則強制。

- [ ] **Step 1: 寫失敗的離線測試**

在 `docs/agent-workflow/test_kandev_bootstrap.py` 頂部 import 改為：

```python
from kandev_bootstrap import call, main, WS_NAME, COLUMNS, WORKFLOWS, SEED_TASKS, Q_NAME, Q_COLUMNS, WORKFLOW_COLUMNS
```

新增（放在 `test_state` 之前）：

```python
def _types(col):
    return [a["type"] for a in col.get("events", {}).get("on_enter", [])]


def test_q_columns_shape():
    """Offline: no Kandev needed."""
    names = [c["name"] for c in Q_COLUMNS]
    assert names == ["Backlog", "QA Run", "Reported", "Triage (graph)", "Decide (gstack)", "Fix (worktree)",
                     "Merge-ready", "Re-verify (QA)", "Done", "Closed"], names
    by = {c["name"]: c for c in Q_COLUMNS}
    for n in ("Backlog", "Reported", "Merge-ready"):
        assert _types(by[n]) == [], f"{n} must not start an agent"
    for n in ("QA Run", "Triage (graph)", "Decide (gstack)", "Fix (worktree)", "Re-verify (QA)", "Done", "Closed"):
        assert "auto_start_agent" in _types(by[n]), n
        assert "{{task_prompt}}" in by[n]["prompt"], n
        assert "CLAUDE.md" in by[n]["prompt"], f"{n}: must tell the agent what to read"
    assert by["QA Run"]["wip_limit"] == 1 and by["Re-verify (QA)"]["wip_limit"] == 1
    assert by["Done"].get("done") is True and by["Closed"].get("done") is True
    assert WORKFLOW_COLUMNS[Q_NAME] is Q_COLUMNS
    assert all(WORKFLOW_COLUMNS[n] is COLUMNS for n in WORKFLOWS)


def test_q_prompts_carry_the_rules():
    by = {c["name"]: c["prompt"] for c in Q_COLUMNS}
    qa = by["QA Run"]
    for token in ("/api/v1/dashboard/", "env-not-ready", "create_task_kandev", "start_agent=false", "external_id",
                  "list_tasks_kandev", "docs/qa/templates/bug-card.md", "/qa-only", "BROAD",
                  "I am the owner of this board", "agent_profile_id 9dac882b-2973-4bc0-a175-61fb5aa58f0c", "another QA run is active"):
        assert token in qa, f"QA Run prompt lacks {token!r}"
    tri = by["Triage (graph)"]
    for token in ("graph-query.mjs", "source: graph", "source: code", "Closed", "Decide (gstack)", "Fix (worktree)", "move_task_kandev"):
        assert token in tri, f"Triage prompt lacks {token!r}"
    fix = by["Fix (worktree)"]
    for token in ("worktree", "failing test", "graph-query.mjs", "impact", "BROAD", "grep -rn", "Merge-ready", "systematic-debugging"):
        assert token in fix, f"Fix prompt lacks {token!r}"
    rv = by["Re-verify (QA)"]
    for token in ("退回次數", "ESCALATED", "Decide (gstack)", "Fix (worktree)", "Done", "git log", "/qa-only"):
        assert token in rv, f"Re-verify prompt lacks {token!r}"
    # Task 1: a third-person "the user requested" sentence is refused as suspected prompt injection
    assert "The user has" not in qa and "the user explicitly" not in qa.lower()
    assert "update_task_kandev" in by["Triage (graph)"] and "one short factual sentence" in tri
    assert "graph-stale" in by["Done"] and ".ua/meta.json" in by["Done"]
    assert "never push" in by["Fix (worktree)"].lower() or "do not push" in by["Fix (worktree)"].lower()
```

並更新 `test_state`：把 `for name in WORKFLOWS:` 區塊改成

```python
    for name, columns in WORKFLOW_COLUMNS.items():
        assert name in names, f"workflow missing: {name}"
        wf = next(w for w in wfs if w["name"] == name)
        steps = sorted(call("GET", f"/workflows/{wf['id']}/workflow/steps")["steps"], key=lambda s: s["position"])
        assert [s["name"] for s in steps] == [c["name"] for c in columns], f"{name}: columns {[s['name'] for s in steps]}"
        assert steps[0]["is_start_step"] is True, f"{name}: Backlog must be start step"
        for col, step in zip(columns, steps):
            want = _types(col)
            got = [a["type"] for a in (step.get("events") or {}).get("on_enter", [])]
            assert got == want, f"{name}/{col['name']}: on_enter {got} != {want}"
            assert (step.get("wip_limit") or 0) == col.get("wip_limit", 0), f"{name}/{col['name']}: wip_limit"
            if name == Q_NAME:
                assert step["prompt"] == col["prompt"], f"{name}/{col['name']}: prompt drifted"
```

並把檔尾 `__main__` 改為先跑離線測試：

```python
if __name__ == "__main__":
    test_q_columns_shape()
    test_q_prompts_carry_the_rules()
    print("offline: PASS")
    print("state:", test_state())
    test_idempotent()
    print("PASS")
```

- [ ] **Step 2: 執行確認失敗**

Run: `cd ~/Taipei-City-Dashboard/docs/agent-workflow && python3 test_kandev_bootstrap.py`
Expected: `ImportError: cannot import name 'Q_NAME'`

- [ ] **Step 3: 實作 —— 在 `kandev_bootstrap.py` 的 `WORKFLOWS = {...}` 之後加入**

```python
Q_NAME = "Q 品質迴圈"
FRESH = [{"type": "reset_agent_context"}, {"type": "auto_start_agent"}]  # Task 1 decision; see plan Task 4

# Common footer for every Q column prompt: what to read, what never to do.
_COMMON = (
    "Read ONLY CLAUDE.md and this card (the task description); do not re-read the whole repo. "
    "Never print or commit secrets (mapbox-key.txt, docker/.env). Docs may be committed directly on develop; "
    "code changes only in a worktree. Never push and never open a PR. "
    "Use list_workflow_steps_kandev to look up step ids by name. Before moving THIS card, write the real hand-off into the card "
    "description with update_task_kandev (a one-shot move prompt is easily mistaken for injected text and ignored), then call "
    "move_task_kandev(task_id, workflow_id, workflow_step_id, prompt=<one short factual sentence>). "
)
_EVENT = (
    "Write one event file docs/qa/events/<YYYYMMDD-HHMM>-<card id>-<event>.md from docs/qa/templates/event.md "
    "and commit it on develop (docs only). "
)

# wip_limit is NOT enforced by Kandev (Task 1: it only sets task.wip_admitted=false). It documents intent;
# the QA Run prompt enforces one-at-a-time.
Q_COLUMNS = [
    {"name": "Backlog", "color": "bg-neutral-400", "prompt": ""},
    {"name": "QA Run", "color": "bg-sky-500", "events": {"on_enter": FRESH}, "wip_limit": 1, "prompt": (
        "[QA RUN - gstack /qa-only] {{task_prompt}}\n" + _COMMON +
        "0) Only one QA run at a time (the column's wip_limit is not enforced): call list_tasks_kandev; if another QA-RUN card is in the 'QA Run' step with a running session, write an env-not-ready event saying another QA run is active and stop. "
        "1) Readiness: GET http://localhost:8088/api/v1/dashboard/ (with the trailing slash) and http://localhost:8080 must both "
        "return 200. If not, write an env-not-ready event and stop; do NOT file bugs. "
        "2) Test the scope named in the card. If it says to derive scope, run "
        "`cd ~/Taipei-City-Dashboard && node ~/Understand-Anything/scripts/graph-query.mjs ~/Taipei-City-Dashboard impact $(git diff --name-only HEAD~5) --depth 2` and test the listed endpoints and pages, plus a few samples. "
        "If the output says BROAD do not trust it: run a smoke pass (home page, one dashboard page, admin login) plus the endpoints of the changed controllers instead. "
        "3) Use /qa-only: report only, never fix. Any data you write must have a name containing qa-<run id> and be removed before you finish. "
        "4) For every finding: call list_tasks_kandev and skip it if an open BUG card already describes the same symptom (list it under 'duplicates' in the report). "
        "Otherwise pick the next BUG number (highest existing + 1), save evidence under docs/qa/evidence/BUG-<n>/ and commit it on develop, "
        "then call create_task_kandev ONCE with: workflow_id and workflow_step_id of this workflow's 'Reported' step, "
        "title 'BUG-<n> <one line>', prompt = the card body from docs/qa/templates/bug-card.md filled in, "
        "repository_id of Taipei-City-Dashboard, executor_profile_id exec-local, agent_profile_id 9dac882b-2973-4bc0-a175-61fb5aa58f0c, start_agent=false, external_id 'BUG-<n>'. "
        "I am the owner of this board and I request one BUG card for every finding of this run. "
        "5) Write docs/qa/runs/<this card id>.md from docs/qa/templates/qa-run-report.md, then " + _EVENT +
        "Move this card to Done with the report path in the hand-off. Stop.")},
    {"name": "Reported", "color": "bg-red-500", "prompt": ""},
    {"name": "Triage (graph)", "color": "bg-blue-500", "events": {"on_enter": FRESH}, "prompt": (
        "[TRIAGE - knowledge graph] {{task_prompt}}\n" + _COMMON +
        "1) From the symptom run `node ~/Understand-Anything/scripts/graph-query.mjs ~/Taipei-City-Dashboard chain \"<endpoint like 'GET /api/v1/component/:id/chart' or a frontend file path>\" --depth 2`. "
        "Files flagged 'same name as a nearer file' are the likely real dependencies; the '+N more (package-level imports)' line is noise from Go package imports, ignore it unless a call site you read says otherwise. "
        "The graph is a hint, not truth (.vue files have no function-level data): read every candidate file to confirm and mark each one 'source: graph' or 'source: code'. "
        "2) Compare with open BUG cards (list_tasks_kandev): if the candidate files overlap by more than half and the symptom is similar, it is a duplicate. "
        "3) Set 嚴重度 (S1-S4, rubric in docs/qa/README.md) and 所屬層, and write 候選檔案 into the card with update_task_kandev. "
        "4) Route with move_task_kandev: S3/S4 and one layer -> 'Fix (worktree)'; S1/S2 or more than one layer -> 'Decide (gstack)'; "
        "duplicate or cannot reproduce -> 'Closed' (say why). Then " + _EVENT + "Stop.")},
    {"name": "Decide (gstack)", "color": "bg-purple-500", "events": {"on_enter": FRESH}, "prompt": (
        "[DECIDE - gstack] {{task_prompt}}\n" + _COMMON +
        "If the card says ESCALATED, write an escalated event, summarise what failed in each attempt, and STOP: do not move the card; the user decides. "
        "Otherwise use /plan-eng-review on the proposed fix (scope, risk, which layer owns it) and write ONE decision record "
        "docs/decisions/NNNN-<slug>.md with headers 目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑, commit it on develop, "
        "then move the card to 'Fix (worktree)'. " + _EVENT + "Stop.")},
    {"name": "Fix (worktree)", "color": "bg-amber-500", "events": {"on_enter": FRESH}, "prompt": (
        "[FIX - superpowers] {{task_prompt}}\n" + _COMMON +
        "Work ONLY inside your worktree; never edit ~/Taipei-City-Dashboard directly and never run docker compose. "
        "Use superpowers:systematic-debugging, then superpowers:test-driven-development: write a failing test that reproduces the bug first, "
        "then the minimal fix, then green; commit on the worktree branch. If the bug cannot be reproduced by a worktree-level test, "
        "say what evidence the re-verifier should use instead. "
        "Then compute the impact: `node ~/Understand-Anything/scripts/graph-query.mjs ~/Taipei-City-Dashboard impact <the files you changed> --depth 2` and write the affected endpoints, pages and tests into 影響範圍. "
        "For Go files the result is usually BROAD (package-level imports): then instead run `grep -rn '<each changed function name>' ~/Taipei-City-Dashboard/Taipei-City-Dashboard-BE --include='*.go'` and list those call sites, their endpoints and tests in 影響範圍. "
        "Do not merge. Move the card to 'Merge-ready' with the branch name and commit sha in the hand-off, and " + _EVENT.lower() + "Stop.")},
    {"name": "Merge-ready", "color": "bg-teal-500", "prompt": (
        "[MERGE-READY - human gate] {{task_prompt}}\n"
        "Do nothing until the user approves. After approval use superpowers:finishing-a-development-branch "
        "(local merge into develop; do not push). After merging, the user moves the card to 'Re-verify (QA)' once FE and BE serve the new code.")},
    {"name": "Re-verify (QA)", "color": "bg-orange-500", "events": {"on_enter": FRESH}, "wip_limit": 1, "prompt": (
        "[RE-VERIFY - gstack /qa-only] {{task_prompt}}\n" + _COMMON +
        "You are a fresh session and did not write the fix. 1) Confirm the fix is on develop: `git log develop --oneline -20` must show the commit named in the card; if not, move the card back to 'Merge-ready' and stop. "
        "2) Readiness probe as in QA Run (a not-ready environment is not a failure: write env-not-ready and stop). "
        "3) With /qa-only run the original 重現步驟, then every item in 影響範圍. Save evidence under docs/qa/evidence/BUG-<n>/. "
        "4) PASS -> move to 'Done'. FAIL -> add 1 to 退回次數 in the card and attach the new evidence; "
        "if the new 退回次數 is 1 or 2 move the card to 'Fix (worktree)'; if it would be 3 or more, write the word ESCALATED into the card, move it to 'Decide (gstack)' and stop. "
        "Never move a card to Done on a FAIL. " + _EVENT + "Stop.")},
    {"name": "Done", "color": "bg-green-500", "done": True, "events": {"on_enter": FRESH}, "prompt": (
        "[DONE - PM] {{task_prompt}}\n" + _COMMON +
        "Write a verified-pass event (for a QA-RUN card, a run-finished summary line). Then check graph freshness: compare "
        "the gitCommitHash in .ua/meta.json with `git -C ~/Taipei-City-Dashboard rev-parse develop`; if they differ, write a second event "
        "graph-stale telling the user to run /understand (incremental) and then `node ~/Understand-Anything/scripts/augment-gin-vue.mjs ~/Taipei-City-Dashboard`. "
        "Commit the event files on develop and stop. Do not update MEMORY.md.")},
    {"name": "Closed", "color": "bg-neutral-500", "done": True, "events": {"on_enter": FRESH}, "prompt": (
        "[CLOSED - PM] {{task_prompt}}\n" + _COMMON +
        "The card was closed as duplicate, will-not-fix or cannot-reproduce. Write a closed event stating the reason and, for a duplicate, the surviving BUG number. Commit it on develop and stop.")},
]

WORKFLOW_COLUMNS = {name: COLUMNS for name in WORKFLOWS}
WORKFLOW_COLUMNS[Q_NAME] = Q_COLUMNS
WORKFLOW_DESCS = {**WORKFLOWS, Q_NAME: "QA 巡檢 → bug → Fix → 複驗 → 摘要檔（手動觸發 QA）"}
SYNCED = {Q_NAME}  # workflows whose existing steps are updated in place (prompt, events, wip_limit)
```

並把 `ensure_steps` 與 `main` 改成：

```python
def step_payload(wf_id, pos, col):
    body = {
        "workflow_id": wf_id, "name": col["name"], "position": pos, "color": col["color"],
        "prompt": col["prompt"], "allow_manual_move": True, "is_start_step": pos == 0,
        "stage_type": "custom", "complete_task_on_enter": bool(col.get("done")),
    }
    if col.get("events"):
        body["events"] = col["events"]
    if col.get("wip_limit"):
        body["wip_limit"] = col["wip_limit"]
    return body


def ensure_steps(wf_id, columns=COLUMNS, sync=False):
    existing = {s["name"]: s for s in (call("GET", f"/workflows/{wf_id}/workflow/steps")["steps"] or [])}
    for pos, col in enumerate(columns):
        cur = existing.get(col["name"])
        if cur is None:
            call("POST", "/workflow/steps", step_payload(wf_id, pos, col))
            continue
        if sync:
            want = {"prompt": col["prompt"], "events": col.get("events") or {}, "wip_limit": col.get("wip_limit", 0)}
            have = {"prompt": cur.get("prompt") or "", "events": cur.get("events") or {}, "wip_limit": cur.get("wip_limit") or 0}
            if want != have:  # the server may normalise events, so a spurious PUT is harmless and idempotent
                call("PUT", f"/workflow/steps/{cur['id']}", want)
    return {s["name"]: s for s in (call("GET", f"/workflows/{wf_id}/workflow/steps")["steps"] or [])}
```

`main()` 內迴圈改為：

```python
    for name, desc in WORKFLOW_DESCS.items():
        wf = ensure_workflow(ws["id"], name, desc)
        steps = ensure_steps(wf["id"], WORKFLOW_COLUMNS[name], sync=name in SYNCED)
        wf_ids[name] = (wf["id"], steps["Backlog"]["id"])
```

（`WORKFLOWS` 保持不變；`ensure_tasks` 與 A 流程不受影響。）

- [ ] **Step 4: 執行離線測試確認通過（先不連 Kandev）**

Run: `cd ~/Taipei-City-Dashboard/docs/agent-workflow && python3 -c "import test_kandev_bootstrap as t; t.test_q_columns_shape(); t.test_q_prompts_carry_the_rules(); print('offline PASS')"`
Expected: `offline PASS`

- [ ] **Step 5: Commit（在 worktree）**

```bash
git add docs/agent-workflow/kandev_bootstrap.py docs/agent-workflow/test_kandev_bootstrap.py
TOK=$(tr -d '[:space:]' < ~/Taipei-City-Dashboard/mapbox-key.txt); git diff --cached | grep -qF -- "$TOK" && echo LEAK || echo ok
git commit -m "feat: add Q quality-loop workflow columns to Kandev bootstrap" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 合併並套用到即時 Kandev

**Files:** 無新增；執行既有腳本。

- [ ] **Step 1: 請使用者核准把 `feature/qa-docs`（Task 3+4）合併進 `develop`**

附上 `git log develop..feature/qa-docs --oneline` 與 `git diff develop...feature/qa-docs --stat`。核准後才繼續；用 `superpowers:finishing-a-development-branch` 做本機 merge（不 push）。

- [ ] **Step 2: 在整合 checkout 套用**

Run: `cd ~/Taipei-City-Dashboard && python3 docs/agent-workflow/kandev_bootstrap.py`
Expected: `workspace=… repo=… workflows=3`（A、B、Q；若先前已有第三條，數字依實際），無錯誤。

- [ ] **Step 3: 跑完整測試（離線 + 即時 + 冪等）**

Run: `cd ~/Taipei-City-Dashboard && python3 docs/agent-workflow/test_kandev_bootstrap.py`
Expected: 依序輸出 `offline: PASS`、`state: (…)`、`PASS`。再執行一次 `kandev_bootstrap.py`，確認 Q workflow 欄位數仍是 10（沒有重複）。

- [ ] **Step 4: 在 Kandev 介面目視確認**

打開 `http://127.0.0.1:38429`，確認 `Q 品質迴圈` 看板有 10 欄、`QA Run` 與 `Re-verify (QA)` 顯示 WIP 限制 1。

---

### Task 6: 端到端演練（兩輪）

使用 `claude-acp`，會消耗額度；演練前先確認服務就緒：`curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8088/api/v1/dashboard/` 與 `http://localhost:8080` 都是 200。

**演練 A：完整正向流程（用真實的小問題）**

候選：`MEMORY.md` 已記錄前端 `Taipei-City-Dashboard-FE/index.html:31,39` 會把瀏覽資料送到上游 GA（`G-0KD9XLZ7W3`）。這是真的問題、單一層、S3，也正是 B 階段候選客製。

- [ ] **Step 1: 建立 `QA-RUN-1` 卡並觸發**

在 `Q 品質迴圈` 的 `Backlog` 建卡，標題 `QA-RUN-1 前端外送追蹤巡檢`，描述用 `docs/qa/templates/qa-run-card.md` 填入，範圍寫「檢查前端是否向第三方（Google Analytics）送出請求，並隨手檢查首頁、儀表板頁載入」。把卡拖進 `QA Run`。
Expected: agent 啟動；產生 `docs/qa/runs/QA-RUN-1.md`、至少一張 `BUG-1` 卡落在 `Reported`（`external_id` 為 `BUG-1`）、事件檔；`QA-RUN-1` 進 `Done`。若 agent 回報 `create_task_kandev` 不可用，記下錯誤，改用 Task 1 的備案（見 spec §8 開放問題 1）後重做本步。

- [ ] **Step 2: Triage → Fix**

把 `BUG-1` 拖進 `Triage (graph)`。Expected: 卡描述被補上嚴重度、所屬層、候選檔案（含 `Taipei-City-Dashboard-FE/index.html`，標明來源），並被移到 `Fix (worktree)`（S3、單一層）。檢查候選檔案確實包含真正要改的 `index.html`。

- [ ] **Step 3: Fix → Merge-ready**

Expected: worktree 分支上有一個失敗測試先行的 commit 與修復 commit；卡的 `影響範圍` 已填；卡移到 `Merge-ready`。

- [ ] **Step 4: 使用者核准合併並載入新碼**

核准後本機 merge。FE 容器是否自動載入新碼依 spec §8 開放問題 6：若沒有，在整合 checkout 重啟 `dashboard-fe`（`cd docker && docker compose restart dashboard-fe`），確認 `curl -s http://localhost:8080 | grep -c G-0KD9XLZ7W3` 輸出 0。再把卡拖進 `Re-verify (QA)`。

- [ ] **Step 5: 複驗 PASS**

Expected: 新 session（不記得修復過程）執行重現步驟與影響範圍，卡移到 `Done`，產生 `verified-pass` 事件；`Done` 欄 agent 比對 `.ua/meta.json` 與 `develop` 的 sha，若不同則寫 `graph-stale` 事件。把 Step 1–5 的實際觀察寫進 `docs/agent-workflow/evidence/qa-loop-drill.md`（含卡編號、commit sha、事件檔路徑；不含祕密）。

- [ ] **Step 5b: 彙整摘要檔（驗證 spec §7 的 PM 摘要）**

建一張 `PM-DIGEST-1` 卡於 `Backlog`，描述寫：「請彙整今天 docs/qa/events/ 的事件檔與 Q 品質迴圈所有卡的狀態，依 docs/qa/templates/digest.md 寫成 docs/qa/digest/<今天日期>.md 並 commit 到 develop。不要建立或修改任何其他卡。」手動啟動該卡的 agent（`Backlog` 沒有自動啟動），Expected: 產生含八個段落的摘要檔（含「待你確認的 Closed」「疑似停滯的卡」），`需要你決定` 段落列出任何 `graph-stale` 或升級項目，且內容與事件檔相符。若實測覺得每次都要手動建卡太麻煩，把「摘要彙整」併進 `QA Run` 欄 prompt 的最後一步，另開變更，不在本計畫範圍。

**演練 B：退回與升級規則**

- [ ] **Step 6: 建立一張無法通過的演練卡，驗證退回計數**

手動建 `BUG-DRILL-1` 於 `Merge-ready`，描述用 `bug-card.md`，`退回次數：1`，重現步驟寫「`curl -s -o /dev/null -w '%{http_code}' http://localhost:8080` 應回 418」，預期 418（實際一定是 200，必然 FAIL），影響範圍寫「無」，並在描述加一行「演練卡，不要修改任何程式」。拖進 `Re-verify (QA)`。
Expected: 複驗 FAIL，`退回次數` 變成 2，卡被移到 `Fix (worktree)`，產生 `verified-fail` 事件。

- [ ] **Step 7: 第二次失敗應升級**

把同一張卡手動拖回 `Re-verify (QA)`（模擬 Fix 之後）。
Expected: 複驗再 FAIL，新的退回次數會是 3，卡描述含 `ESCALATED`，卡被移到 `Decide (gstack)`，agent 寫 `escalated` 事件；`Decide` 欄 agent 看到 `ESCALATED` 後停止、不移動卡。

- [ ] **Step 8: 清理演練卡並記錄**

把 `BUG-DRILL-1` 移到 `Closed`（原因：演練），確認產生 `closed` 事件。把演練 B 的觀察追加到 `docs/agent-workflow/evidence/qa-loop-drill.md`，然後 commit（文件類，直接在 `develop`）：

```bash
cd ~/Taipei-City-Dashboard
git add docs/agent-workflow/evidence/qa-loop-drill.md docs/qa
TOK=$(tr -d '[:space:]' < mapbox-key.txt); git diff --cached | grep -qF -- "$TOK" && echo LEAK || echo ok
git commit -m "docs: record QA loop drill results" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 收尾與記憶

**Files:**
- Modify: `CLAUDE.md`（Kandev 段落加一行）
- Modify: `MEMORY.md`（目前狀態與索引）
- Modify: `docs/superpowers/specs/2026-10-07-qa-loop-workflow-design.md`（狀態改為「已實作並驗收」、§8 填入實測結論）

- [ ] **Step 1: 更新三份文件**

`CLAUDE.md` 的 `## Kandev` 清單末尾加：`- 第三條 workflow \`Q 品質迴圈\`（QA→bug→Fix→複驗→摘要檔），規則見 \`docs/qa/README.md\`；QA 手動觸發：建 \`QA-RUN-<n>\` 卡拖進 \`QA Run\`。`
`MEMORY.md`：在「目前狀態」加一條 Q workflow 已建並演練（日期、證據檔 `docs/agent-workflow/evidence/qa-loop-drill.md`），在 spec 索引那行把「草案，待審閱」改為「已實作並演練」；若演練發現新踩坑（例如 BE 合併後需重建映像），加一條到「踩坑與事實」。
spec 的 §8「仍待實測」逐項填入結果。

- [ ] **Step 2: 檢查並 commit**

```bash
cd ~/Taipei-City-Dashboard
bash docs/agent-workflow/check-docs.sh && bash docs/agent-workflow/check-qa-docs.sh
git add CLAUDE.md MEMORY.md docs/superpowers/specs/2026-10-07-qa-loop-workflow-design.md
TOK=$(tr -d '[:space:]' < mapbox-key.txt); git diff --cached | grep -qF -- "$TOK" && echo LEAK || echo ok
git commit -m "docs: mark QA loop workflow implemented and drilled" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

Expected: 兩個檢查都 `PASS`，`ok`，commit 成功。

---

## Self-Review

**Spec coverage**
- §1 成功標準 1（手動 QA-RUN → BUG 卡）：Task 4 的 QA Run prompt、Task 6 演練 A Step 1。
- 成功標準 2（走完欄位、只讀 CLAUDE.md 與卡）：每個 prompt 的 `_COMMON`；Task 4 測試檢查含 `CLAUDE.md`。
- 成功標準 3（複驗不同 session、退回 2 次升級）：`FRESH` 動作 + Re-verify prompt；Task 6 演練 B。
- 成功標準 4（事件檔與摘要）：`_EVENT`、Task 3 模板。摘要檔 `digest/` 的彙整由使用者手動建 `PM-DIGEST` 卡要求，已列為 Task 6 Step 5b 並在演練中驗證；自動化不在本計畫範圍（spec §1 已列為不做）。
- 成功標準 5（無祕密）：Global Constraints 與每個 commit 步驟的比對。
- §3 欄位與 §8 `on_enter`/`wip_limit` 表：Task 4 的 `Q_COLUMNS` 與測試逐欄對照。
- §5 圖的用法：Triage（chain）、Fix（impact）、QA Run（impact 選範圍）、Done（新鮮度）；§5.5 查詢工具：Task 2。
- §8 待實測四項與開放問題 5、6：Task 1 與 Task 6 Step 4。開放問題 7（嚴重度邊界）屬跑幾輪後再調整，不在本計畫。

**Placeholder scan:** 無 TBD；`<n>`、`<YYYYMMDD-HHMM>` 是 prompt 與模板中給 agent 的執行時填空，不是計畫缺漏。Task 4 對 Task 1 結論的分支（`FRESH` 與 `_COMMON` 的 HANDOFF 註解）已寫出兩個選項的具體內容。

**Type consistency:** `Q_NAME`、`Q_COLUMNS`、`WORKFLOW_COLUMNS`、`WORKFLOW_DESCS`、`SYNCED`、`ensure_steps(wf_id, columns, sync)`、`step_payload(wf_id, pos, col)` 在 Task 4 的測試與實作一致；`graph-query.mjs` 的 `findStart`/`traverse`/`summarize` 在 Task 2 測試與實作簽名一致；bug 卡欄位名（`嚴重度`、`所屬層`、`候選檔案`、`影響範圍`、`退回次數`）在 Task 3 模板、檢查腳本與 Task 4 prompt 一致。

**已知風險（執行時要留意）**
0. **圖對後端的精確度有限（撰寫本計畫時已實測）**：Go 的 import 是套件層級，`impact` 改任何 `models/` 檔都會觸及全部 40 個 endpoint。Task 2 因此加入 `BROAD` 警告與同名檔提示，Task 4 的 QA Run 與 Fix prompt 在 `BROAD` 時改用 smoke 測試與 `grep` 呼叫點。這是工具的設計限制，不是 bug；若日後要精確，需要 Go 的符號級分析（例如 gopls），不在本計畫範圍。
1. Task 1 若發現 `reset_agent_context` 不隔離上下文，整套「每欄乾淨 session」設計要回 spec 修改，不得硬套 Task 4。
2. `PUT /workflow/steps/:id` 對 `events` 為空物件的行為未實測；Task 5 Step 3 的冪等檢查會暴露問題。
3. 演練 A 依賴 FE 在合併後能載入新碼；若 BE 也被牽涉要重建映像（首次需 1 小時以上，見 `MEMORY.md`），本演練刻意選 FE-only 問題避開。
