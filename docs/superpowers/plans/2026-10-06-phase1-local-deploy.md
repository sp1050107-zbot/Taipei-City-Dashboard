# Phase 1：本地部署 + Agent 工作流基礎 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Kandev 建好專案的 workspace/workflow/task，補齊 `CLAUDE.md` / `AGENTS.md` / `MEMORY.md`，並用官方 Docker 全容器方式把 Taipei-City-Dashboard 在本機跑起來、取得驗收證據。

**Architecture:** 三層分工——gstack 做決策與把關、GSD 保存背景與交接、superpowers 以 TDD 執行。每個計畫 Task 對應一個 Kandev task（一個 Claude session）。所有會進 git 的程式碼/腳本變更走 worktree；只有文件類檔案可直接在整合 checkout 提交。

**Tech Stack:** Docker 29 / docker compose、PostGIS 16、Redis、Qdrant、Vue 3 + Vite（FE）、Go 1.25 + Gin（BE）、bash、python3、Kandev REST API。

**Spec:** `docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md`

**範圍說明：** 本計畫只涵蓋 spec 的 Phase 1 與其前置（Kandev、文件三件組）。Phase 2（混合式開發環境）在 Phase 1 驗收後另寫一份計畫，因為它的細節取決於 Phase 1 實測到的問題。

## Global Constraints

- 整合 checkout：`~/Taipei-City-Dashboard`，分支 `develop`。
- 程式碼、腳本、compose、設定變更：一律在 worktree（`~/Taipei-City-Dashboard-worktrees/<name>`，分支 `feature/<slug>`）開發與測試，通過後才本機 merge 回 `develop`。
- 只有 `CLAUDE.md`、`AGENTS.md`、`MEMORY.md`、`docs/`、`.planning/` 可直接在整合 checkout commit。
- 不 `git push`、不對 upstream 發 PR，除非使用者明確指示。
- Mapbox token 與所有產生的密碼：不得出現在對話輸出、log、commit。token 檔 `mapbox-key.txt` 已列入 `.git/info/exclude`；`docker/.env` 已被 `.gitignore` 忽略。
- 只用 Claude Code session（Kandev agent：`claude-acp` Default profile）；不啟用 Codex。
- 不設定任何 LLM/AI 金鑰；Qdrant 可啟動但 AI 功能維持停用。
- Kandev：`http://127.0.0.1:38429`（v0.96.0）。既有 workspace `kandev-assistant` 不得修改。
- 檔名使用 `AGENTS.md`（不是 `AGENT.md`）；`.planning/` 納入 git。
- 交接檔固定五個標頭：`目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`。
- worktree 只看得到已 commit 的內容：派 task 前，交接檔必須已 commit 到 `develop`。
- compose 只在整合 checkout（`~/Taipei-City-Dashboard/docker`）執行：compose 檔使用固定 `container_name`，同一台機器只能有一組堆疊；Kandev worktree task 不得執行 compose。
- Phase 1 只啟動：`redis postgres-data postgres-manager qdrant`（基礎設施）與 `dashboard-fe dashboard-be`（應用）。不啟動 nginx、pgAdmin、`vector-db-upgrade`（決策記錄 `docs/decisions/0001-phase1-deploy-approach.md` ruling 3–5）。
- BE 的 ONNX 嵌入模型為必經（`app/app.go:47`），沒有「純 golang image」備案。
- 上游 `.gitignore` 第 29 行有 `*.sh`：本計畫新增的 shell 腳本一律用 `git add -f` 指定檔名加入（不修改上游 `.gitignore`）。
- 本機 git 尚未設定 `user.name` / `user.email`（commit 作者目前自動推測為 `opsai <opsai@007MacBook-Pro-4.local>`）；此項由使用者決定是否設定，本計畫不代為修改全域設定。

## Review Focus

1. **埠號已被占用**（80/443/8080/8088/5432/6333/6334/8889）：預檢必須明確失敗並列出占用者，不得強行啟動或殺掉別人的行程。→ Task 6 Step 4（`lsof` 迴圈）。
2. **token 檔格式異常**（有結尾換行/空白、檔案不存在、內容為空）：產生器必須去除空白、缺檔時警告但不中斷、且不得把 token 印出。→ Task 5 測試 1、4。
3. **祕密外洩到 git**（`docker/.env`、`mapbox-key.txt`、密碼被 `git add`）：每次 commit 前必須檢查 staged diff 沒有 token 與密碼樣式。→ Task 5 Step 7、Task 9。
4. **init 靜默失敗與重跑**：`initial.go` 吞掉錯誤、`psql -f` 沒有 `ON_ERROR_STOP`，所以 `Exited (0)` 不代表資料載入成功；重跑會重複寫入或靜默出錯。驗收只看資料列數，且**不重跑**，重置用刪 volume。→ Task 7 Step 2–5。
5. **就緒探測誤判**：`/api/v1/dashboard`（無結尾斜線）會得到 301；必須探測 `/api/v1/dashboard/`，並對照 `docker logs`。→ Task 8 Step 3。

---

## 檔案結構

| 路徑 | 動作 | 責任 |
|---|---|---|
| `docs/agent-workflow/kandev_bootstrap.py` | Create | 冪等地建立 Kandev workspace / repo / workflow / steps / 種子 task |
| `docs/agent-workflow/test_kandev_bootstrap.py` | Create | 對實機 Kandev 驗證上述結果與冪等性 |
| `CLAUDE.md` | Create | Claude 每 session 自動載入的精簡入口（≤100 行） |
| `AGENTS.md` | Create | 跨 agent 共用的專案規則 |
| `MEMORY.md` | Create | 長期記憶索引（只放索引） |
| `docs/agent-workflow/check-docs.sh` | Create | 檢查三件組格式、連結、無祕密 |
| `.planning/codebase/*` | Create（GSD 產出） | 程式碼地圖 |
| `docs/decisions/0001-phase1-deploy-approach.md` | Create（gstack 產出） | Phase 1 決策記錄 |
| `docs/agent-workflow/make-env.sh` | Create（worktree） | 由 `.env.template` 產生本機專用 `docker/.env` |
| `docs/agent-workflow/test-make-env.sh` | Create（worktree） | `make-env.sh` 的測試 |
| `docs/agent-workflow/evidence/phase1-verification.md` | Create | Phase 1 驗收證據（不含祕密） |

---

### Task 1: Kandev workspace、workflow 與種子 task

**Files:**
- Create: `docs/agent-workflow/kandev_bootstrap.py`
- Test: `docs/agent-workflow/test_kandev_bootstrap.py`

**Interfaces:**
- Produces: Kandev 中存在 workspace `taipei-city-dashboard`；兩條 workflow `A 部署與研究`、`B 客製開發`，各有 7 個欄位（順序見下）；workflow A 的 Backlog 欄有 8 張種子 task（`P1-01`…`P1-08`）。`kandev_bootstrap.py` 提供 `call(method, path, body=None) -> dict` 與 `main()`；測試匯入 `call`、`WS_NAME`、`COLUMNS`。
- Consumes: Kandev REST（已讀原始碼確認的請求格式）：
  - `POST /workspaces` `{name, description, default_executor_id, default_agent_profile_id}`（建立時 Kandev 會自動附帶一條名為 `Kanban` 的 workflow，保留不動；task 前綴由 Kandev 自動指派，無法於建立時指定）。
  - `POST /workspaces/{id}/repositories` `{name, source_type, local_path, provider, provider_host, provider_owner, provider_name, default_branch, worktree_branch_prefix, worktree_branch_template, pull_before_worktree}`。
  - `POST /workflows` `{workspace_id, name, description}`。
  - `POST /workflow/steps` `{workflow_id, name, position, color, prompt, allow_manual_move, is_start_step, stage_type, complete_task_on_enter}`。
  - `POST /tasks` `{workspace_id, workflow_id, workflow_step_id, title, description, repositories:[{repository_id, base_branch}], executor_id}`。

欄位（兩條 workflow 相同）：`Backlog`(起始) → `Decide (gstack)` → `Context (GSD)` → `Build (worktree)` → `Verify` → `Merge-ready` → `Done`。

- [ ] **Step 1: 寫失敗的測試**

建立 `docs/agent-workflow/test_kandev_bootstrap.py`：

```python
#!/usr/bin/env python3
"""Verifies the live Kandev state created by kandev_bootstrap.py."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from kandev_bootstrap import call, main, WS_NAME, COLUMNS, WORKFLOWS, SEED_TASKS


def snapshot():
    ws = [w for w in call("GET", "/workspaces")["workspaces"] if w["name"] == WS_NAME]
    assert len(ws) == 1, f"expected exactly 1 workspace named {WS_NAME}, got {len(ws)}"
    ws = ws[0]
    wfs = [w for w in call("GET", "/workflows")["workflows"] if w["workspace_id"] == ws["id"]]
    repos = call("GET", f"/workspaces/{ws['id']}/repositories")["repositories"]
    tasks = call("GET", f"/workspaces/{ws['id']}/tasks")["tasks"]
    return ws, wfs, repos, tasks


def test_state():
    ws, wfs, repos, tasks = snapshot()
    names = {w["name"] for w in wfs}
    for name in WORKFLOWS:
        assert name in names, f"workflow missing: {name}"
        wf = next(w for w in wfs if w["name"] == name)
        steps = sorted(call("GET", f"/workflows/{wf['id']}/workflow/steps")["steps"], key=lambda s: s["position"])
        assert [s["name"] for s in steps] == [c["name"] for c in COLUMNS], f"{name}: columns {[s['name'] for s in steps]}"
        assert steps[0]["is_start_step"] is True, f"{name}: Backlog must be start step"
    assert any(r["local_path"] == os.path.expanduser("~/Taipei-City-Dashboard") for r in repos), "repo not registered"
    repo = next(r for r in repos if r["local_path"] == os.path.expanduser("~/Taipei-City-Dashboard"))
    assert repo["default_branch"] == "develop"
    assert repo["pull_before_worktree"] is False, "must not pull: develop has unpushed local commits"
    titles = {t["title"] for t in tasks}
    for t in SEED_TASKS:
        assert t["title"] in titles, f"seed task missing: {t['title']}"
    return len(wfs), len(repos), len(tasks)


def test_idempotent():
    before = snapshot()
    main()
    after = snapshot()
    assert (len(before[1]), len(before[2]), len(before[3])) == (len(after[1]), len(after[2]), len(after[3])), "second run created duplicates"


if __name__ == "__main__":
    print("state:", test_state())
    test_idempotent()
    print("PASS")
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd ~/Taipei-City-Dashboard && python3 docs/agent-workflow/test_kandev_bootstrap.py`
Expected: FAIL，`ModuleNotFoundError: No module named 'kandev_bootstrap'`

- [ ] **Step 3: 寫最小實作**

建立 `docs/agent-workflow/kandev_bootstrap.py`：

```python
#!/usr/bin/env python3
"""Create the Kandev workspace, repository, workflows, steps and seed tasks. Idempotent by name."""
import json
import os
import urllib.error
import urllib.request

BASE = os.environ.get("KANDEV_URL", "http://127.0.0.1:38429/api/v1")
WS_NAME = "taipei-city-dashboard"
REPO_PATH = os.path.expanduser("~/Taipei-City-Dashboard")
AGENT_PROFILE = "9dac882b-2973-4bc0-a175-61fb5aa58f0c"  # claude-acp "Default (recommended)"
EXEC_WORKTREE = "exec-worktree"
EXEC_LOCAL = "exec-local"
PLAN = "docs/superpowers/plans/2026-10-06-phase1-local-deploy.md"

COLUMNS = [
    {"name": "Backlog", "color": "bg-neutral-400", "prompt": ""},
    {"name": "Decide (gstack)", "color": "bg-purple-500", "prompt": (
        "[DECIDE - gstack] {{task_prompt}}\n"
        "Only decide; do not write product code. Use the gstack skill named in the task "
        "(/office-hours, /plan-eng-review, /plan-ceo-review). Read only CLAUDE.md and the handoff file named in the task.\n"
        "Write ONE decision record to docs/decisions/NNNN-<slug>.md with headers: 目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑. "
        "Commit it on develop (docs only). Stop.")},
    {"name": "Context (GSD)", "color": "bg-blue-500", "prompt": (
        "[CONTEXT - GSD] {{task_prompt}}\n"
        "Use the GSD skill named in the task (gsd-map-codebase, gsd-onboard, gsd-plan-phase, gsd-pause-work). "
        "Read only CLAUDE.md and the handoff file named in the task. Write state under .planning/. "
        "End with the five-header handoff (目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑) and commit on develop. Stop.")},
    {"name": "Build (worktree)", "color": "bg-amber-500", "prompt": (
        "[BUILD - superpowers] {{task_prompt}}\n"
        "Work ONLY inside your worktree; never edit ~/Taipei-City-Dashboard directly. "
        "Use superpowers:test-driven-development and follow the named task in the plan exactly: failing test first, "
        "then minimal implementation, then green. Commit on your worktree branch. Never print or commit secrets. Stop at green.")},
    {"name": "Verify", "color": "bg-orange-500", "prompt": (
        "[VERIFY] {{task_prompt}}\n"
        "Use superpowers:verification-before-completion: run the verification commands for real and paste the actual output "
        "(no secrets) into docs/agent-workflow/evidence/. Run gstack /review on the diff; /qa for UI work. "
        "Report PASS or FAIL per acceptance criterion.")},
    {"name": "Merge-ready", "color": "bg-teal-500", "prompt": (
        "[MERGE-READY - human gate] {{task_prompt}}\n"
        "Do nothing until the user approves. After approval use superpowers:finishing-a-development-branch "
        "(local merge into develop; do not push).")},
    {"name": "Done", "color": "bg-green-500", "prompt": "", "done": True},
]

WORKFLOWS = {
    "A 部署與研究": "Phase 1：本地部署與學習研究（官方 Docker 全容器）",
    "B 客製開發": "Phase 2 起：混合式開發環境與客製化",
}

SEED_TASKS = [
    {"title": "P1-01 文件三件組 CLAUDE.md / AGENTS.md / MEMORY.md", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 2（{PLAN}）。技能：writing-plans 產出的內容直接建檔。完成條件：bash docs/agent-workflow/check-docs.sh 輸出 PASS，且已 commit 到 develop。"},
    {"title": "P1-02 程式碼地圖（GSD）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 3（{PLAN}）。技能：gsd-map-codebase。交接檔：CLAUDE.md。完成條件：.planning/codebase/ 至少 4 份文件並 commit。"},
    {"title": "P1-03 Phase 1 部署決策（gstack）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 4（{PLAN}）。技能：/plan-eng-review。交接檔：.planning/codebase/ 與該計畫。完成條件：docs/decisions/0001-phase1-deploy-approach.md 含五個標頭並 commit。"},
    {"title": "P1-04 make-env.sh 與 preflight.sh（worktree）", "exec": EXEC_WORKTREE,
     "desc": f"計畫 Task 5、6 Step 1（{PLAN}）。技能：superpowers:test-driven-development。完成條件：test-make-env.sh 輸出 PASS，/review 通過，本機 merge 回 develop。"},
    {"title": "P1-05 起基礎設施（DB/Redis/Qdrant）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 6（{PLAN}）。完成條件：四個容器 healthy/運行，兩個 PostGIS 可連線。"},
    {"title": "P1-06 初始化資料庫與前端相依", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 7（{PLAN}）。完成條件：兩個 DB 有資料表，三個 init 容器 exit 0，並記錄重跑行為。"},
    {"title": "P1-07 起應用（FE/BE/nginx）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 8（{PLAN}）。完成條件：FE:8080、BE:8088 回應，git status 乾淨。"},
    {"title": "P1-08 驗收與收尾", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 9、10（{PLAN}）。技能：/qa-only、verification-before-completion、gsd-extract-learnings。完成條件：docs/agent-workflow/evidence/phase1-verification.md 逐項有證據，MEMORY.md 已更新。"},
]


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> {e.code}: {e.read().decode()[:400]}")


def ensure_workspace():
    for w in call("GET", "/workspaces")["workspaces"]:
        if w["name"] == WS_NAME:
            return w
    return call("POST", "/workspaces", {
        "name": WS_NAME,
        "description": "Taipei-City-Dashboard 本地部署與三層 agent 分工（gstack/GSD/superpowers）",
        "default_executor_id": EXEC_WORKTREE,
        "default_agent_profile_id": AGENT_PROFILE,
    })


def ensure_repo(ws_id):
    for r in call("GET", f"/workspaces/{ws_id}/repositories")["repositories"]:
        if r["local_path"] == REPO_PATH:
            return r
    return call("POST", f"/workspaces/{ws_id}/repositories", {
        "name": "Taipei-City-Dashboard", "source_type": "local", "local_path": REPO_PATH,
        "provider": "github", "provider_host": "https://github.com",
        "provider_owner": "sp1050107-zbot", "provider_name": "Taipei-City-Dashboard",
        "default_branch": "develop", "worktree_branch_prefix": "feature/",
        "worktree_branch_template": "feature/{title}-{suffix}",
        "pull_before_worktree": False,
    })


def ensure_workflow(ws_id, name, desc):
    for w in call("GET", "/workflows")["workflows"]:
        if w["workspace_id"] == ws_id and w["name"] == name:
            return w
    return call("POST", "/workflows", {"workspace_id": ws_id, "name": name, "description": desc})


def ensure_steps(wf_id):
    existing = {s["name"]: s for s in call("GET", f"/workflows/{wf_id}/workflow/steps")["steps"]}
    for pos, col in enumerate(COLUMNS):
        if col["name"] in existing:
            continue
        call("POST", "/workflow/steps", {
            "workflow_id": wf_id, "name": col["name"], "position": pos, "color": col["color"],
            "prompt": col["prompt"], "allow_manual_move": True, "is_start_step": pos == 0,
            "stage_type": "custom", "complete_task_on_enter": bool(col.get("done")),
        })
    return {s["name"]: s for s in call("GET", f"/workflows/{wf_id}/workflow/steps")["steps"]}


def ensure_tasks(ws_id, wf_id, backlog_id, repo_id):
    have = {t["title"] for t in call("GET", f"/workspaces/{ws_id}/tasks")["tasks"]}
    for t in SEED_TASKS:
        if t["title"] in have:
            continue
        call("POST", "/tasks", {
            "workspace_id": ws_id, "workflow_id": wf_id, "workflow_step_id": backlog_id,
            "title": t["title"], "description": t["desc"], "executor_id": t["exec"],
            "repositories": [{"repository_id": repo_id, "base_branch": "develop"}],
        })


def main():
    ws = ensure_workspace()
    repo = ensure_repo(ws["id"])
    wf_ids = {}
    for name, desc in WORKFLOWS.items():
        wf = ensure_workflow(ws["id"], name, desc)
        steps = ensure_steps(wf["id"])
        wf_ids[name] = (wf["id"], steps["Backlog"]["id"])
    wf_a, backlog_a = wf_ids["A 部署與研究"]
    ensure_tasks(ws["id"], wf_a, backlog_a, repo["id"])
    print(f"workspace={ws['id']} repo={repo['id']} workflows={len(wf_ids)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: 執行 bootstrap，再跑測試確認通過**

Run: `cd ~/Taipei-City-Dashboard && python3 docs/agent-workflow/kandev_bootstrap.py && python3 docs/agent-workflow/test_kandev_bootstrap.py`
Expected: 先印 `workspace=... repo=... workflows=2`；測試印 `state: (3, 1, 8)` 與 `PASS`（3 條 workflow = 自動的 `Kanban` + 兩條自建；若 Kandev 版本不自動附帶 Kanban 則為 2，兩者皆接受，測試只要求兩條自建 workflow 存在）。

若 `POST` 回 4xx，錯誤訊息會直接印出欄位問題；依訊息修正欄位名稱後重跑（腳本冪等）。

- [ ] **Step 5: 確認既有 workspace 未被改動**

Run: `curl -s http://127.0.0.1:38429/api/v1/workspaces | jq '.workspaces[] | {name, task_prefix}'`
Expected: 同時看到 `kandev-assistant`（prefix `KAN`，不變）與 `taipei-city-dashboard`（記下 Kandev 自動指派的前綴，寫入 Task 10 的 MEMORY.md）。

- [ ] **Step 6: Commit（文件類，直接在 develop）**

```bash
cd ~/Taipei-City-Dashboard
git add docs/agent-workflow/kandev_bootstrap.py docs/agent-workflow/test_kandev_bootstrap.py docs/superpowers/plans/2026-10-06-phase1-local-deploy.md
git commit -m "docs: add Kandev bootstrap for local agent workflow and Phase 1 plan

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

（此兩支腳本屬 `docs/` 下的工具腳本，不是產品程式碼；若使用者希望更嚴格，可改走 worktree，預設不必。）

---

### Task 2: 文件三件組

**Files:**
- Create: `CLAUDE.md`, `AGENTS.md`, `MEMORY.md`
- Test: `docs/agent-workflow/check-docs.sh`

**Interfaces:**
- Produces: `check-docs.sh`（無參數，印 `PASS` 並 exit 0，或 `FAIL: <原因>` 並 exit 1）。`MEMORY.md` 的索引格式 `- [標題](相對路徑) — 說明`，Task 10 沿用。

- [ ] **Step 1: 寫失敗的檢查腳本**

建立 `docs/agent-workflow/check-docs.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FAIL: $*" >&2; exit 1; }

for f in CLAUDE.md AGENTS.md MEMORY.md; do [ -f "$f" ] || fail "$f missing"; done
[ "$(wc -l < CLAUDE.md)" -le 100 ] || fail "CLAUDE.md exceeds 100 lines"
grep -q '^@AGENTS.md' CLAUDE.md || fail "CLAUDE.md must import @AGENTS.md"

# every markdown link target in MEMORY.md must exist
while IFS= read -r target; do
  [ -e "$target" ] || fail "MEMORY.md links to missing path: $target"
done < <(grep -oE '\]\(([^)#]+)' MEMORY.md | sed 's/](//' | grep -v '^http')

# no secrets in the trio
if grep -nE 'pk\.[A-Za-z0-9._-]{20,}|sk-[A-Za-z0-9]{20,}' CLAUDE.md AGENTS.md MEMORY.md >/dev/null; then
  fail "possible secret found in docs trio"
fi
echo PASS
```

- [ ] **Step 2: 執行確認失敗**

Run: `cd ~/Taipei-City-Dashboard && bash docs/agent-workflow/check-docs.sh`
Expected: `FAIL: CLAUDE.md missing`

- [ ] **Step 3: 建立 `AGENTS.md`**

```markdown
# AGENTS.md — Taipei-City-Dashboard（本地 fork）

本檔是所有 agent 共用的專案規則。Claude 由 `CLAUDE.md` 匯入本檔。

## 這是什麼
臺北市城市儀表板（資料視覺化平台）的本機 fork，用於「學習研究（A）」與「客製開發（B）」。
上游：`taipei-doit/Taipei-City-Dashboard`；origin：`sp1050107-zbot/Taipei-City-Dashboard`；預設與整合分支：`develop`。

## 結構
- `Taipei-City-Dashboard-FE/` Vue 3 + Vite 前端（Mapbox GL、deck.gl）
- `Taipei-City-Dashboard-BE/` Go 1.25 + Gin 後端（路由在 `app/routes/router.go`，環境變數在 `global/global.go`）
- `Taipei-City-Dashboard-DE/` 資料工程
- `docker/` compose 檔、`.env.template`、nginx
- `db-sample-data/` 示範資料（`dashboard-demo.sql`、`dashboardmanager-demo.sql`）
- `docs/superpowers/{specs,plans}/` spec 與計畫；`docs/decisions/` 決策記錄；`.planning/` GSD 狀態

## 本機埠號（Phase 1 全容器）
| 服務 | 主機埠 |
|---|---|
| 前端 (Vite) | 8080 |
| 後端 (Gin) | 8088 |
| nginx | 80 / 443 |
| postgres-manager | 5432 |
| qdrant | 6333 / 6334 |
| pgAdmin | 8889 |

## 工作規則
1. 程式碼、腳本、compose、設定的變更：只在 worktree（`~/Taipei-City-Dashboard-worktrees/<name>`，分支 `feature/<slug>`）進行，TDD，通過後才本機 merge 回 `develop`。
2. 只有 `CLAUDE.md`、`AGENTS.md`、`MEMORY.md`、`docs/`、`.planning/` 可直接在整合 checkout commit。
3. 不 `git push`、不對 upstream 發 PR，除非使用者明確指示。
4. 祕密：`mapbox-key.txt`、`docker/.env` 永不 commit、永不印出。commit 前檢查 staged diff。
5. 不設定任何 LLM/AI 金鑰；AI 搜尋功能維持停用。
6. worktree 只看得到已 commit 的內容；交接檔先 commit 再派工。

## 三層分工與交接
- gstack＝決策與把關（`/office-hours`、`/plan-eng-review`、`/review`、`/qa`、`/cso`）
- GSD＝背景與交接（`gsd-map-codebase`、`gsd-plan-phase`、`gsd-pause-work`、`gsd-resume-work`、`gsd-extract-learnings`）
- superpowers＝TDD 執行閉環（`test-driven-development`、`using-git-worktrees`、`verification-before-completion`、`finishing-a-development-branch`）
- 每層結束寫一份交接檔，標頭固定：`目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`。下一層只讀 `CLAUDE.md` + 該交接檔，需要細節時依其中路徑精準讀取。

## 先讀什麼
1. `CLAUDE.md`（本檔經它匯入）
2. 你的 Kandev task 描述裡指名的交接檔
3. `MEMORY.md` 索引中與你的 task 有關的那一條
```

- [ ] **Step 4: 建立 `CLAUDE.md`**

```markdown
@AGENTS.md

# Claude 專用補充

## 角色路由（缺什麼就找哪一層）
| 我缺的是… | 用 | 例 |
|---|---|---|
| 決策（該不該做、範圍、架構取捨） | gstack | `/office-hours` `/plan-eng-review` |
| 背景（專案現況、程式碼地圖、跨 session 交接） | GSD | `gsd-map-codebase` `gsd-resume-work` |
| 執行（TDD、worktree、驗證） | superpowers | `test-driven-development` `verification-before-completion` |

## Kandev
- 網址 `http://127.0.0.1:38429`，workspace `taipei-city-dashboard`，兩條 workflow：`A 部署與研究`、`B 客製開發`。
- 一個 task = 一個 session；欄位順序 Backlog → Decide → Context → Build → Verify → Merge-ready → Done。
- 重建/補種：`python3 docs/agent-workflow/kandev_bootstrap.py`（冪等）。

## Context 快滿時
1. 執行 `gsd-pause-work` 寫交接。
2. 更新 `MEMORY.md`（只加一行索引，細節放獨立檔）。
3. 新 session 用 `gsd-resume-work` 接續。

## 常用檢查
- 文件三件組：`bash docs/agent-workflow/check-docs.sh`
- Kandev 狀態：`python3 docs/agent-workflow/test_kandev_bootstrap.py`
```

- [ ] **Step 5: 建立 `MEMORY.md`**

```markdown
# MEMORY — 長期記憶索引（只放索引，細節在連結檔）

## 規格與計畫
- [設計 spec](docs/superpowers/specs/2026-10-06-local-deploy-and-agent-workflow-design.md) — 目標、三層分工、worktree 紀律、Phase 1/2
- [Phase 1 計畫](docs/superpowers/plans/2026-10-06-phase1-local-deploy.md) — 10 個 Task，對應 Kandev 種子 task P1-01…P1-08

## 已定案決定
- 檔名用 AGENTS.md；.planning/ 納入 git；本輪不接 Codex；不設 AI/LLM 金鑰；Mapbox 用使用者自己的 token（`mapbox-key.txt`，不入 git）。
- 本機 git 尚未設定 user.name/email（使用者決定），不 push。

## 目前狀態
- Phase 1 進行中（見 Kandev workspace `taipei-city-dashboard`）。
```

- [ ] **Step 6: 執行檢查確認通過**

Run: `cd ~/Taipei-City-Dashboard && bash docs/agent-workflow/check-docs.sh`
Expected: `PASS`

- [ ] **Step 7: Commit（文件類，直接在 develop）**

```bash
cd ~/Taipei-City-Dashboard
git add CLAUDE.md AGENTS.md MEMORY.md
git add -f docs/agent-workflow/check-docs.sh   # upstream .gitignore has '*.sh'
git diff --cached | grep -qF "$(tr -d '[:space:]' < ~/Taipei-City-Dashboard/mapbox-key.txt)" && { echo "SECRET IN DIFF"; exit 1; } || true
git commit -m "docs: add CLAUDE.md, AGENTS.md and MEMORY.md for agent context

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: 程式碼地圖（GSD）

**Files:**
- Create: `.planning/codebase/*`（由 GSD 產生，檔名由技能決定）

**Interfaces:**
- Consumes: `CLAUDE.md`、`AGENTS.md`（Task 2）。
- Produces: `.planning/codebase/` 內至少 4 份分析文件，供後續所有 session 作背景；Task 4 與 Phase 2 計畫讀取。

- [ ] **Step 1: 確認前置**

Run: `cd ~/Taipei-City-Dashboard && git status -s && ls CLAUDE.md AGENTS.md MEMORY.md`
Expected: 工作區乾淨（`mapbox-key.txt` 因 exclude 不顯示），三個檔案存在。

- [ ] **Step 2: 在 Claude session 內執行 GSD 地圖**

於 `~/Taipei-City-Dashboard` 開 Claude Code session（或由 Kandev 的 P1-02 task 啟動），執行技能 `gsd-map-codebase`，指示：「這是既有程式碼，目標是學習；請產出 tech / arch / quality / concerns 四類分析。不要修改任何程式碼。」
Expected: `.planning/codebase/` 出現文件。

- [ ] **Step 3: 驗收**

Run: `cd ~/Taipei-City-Dashboard && ls .planning/codebase | wc -l && git status -s | grep -v '^?? .planning/' || true`
Expected: 第一個數字 ≥ 4；第二個指令無輸出（除 `.planning/` 外沒有其他變更，代表沒動到程式碼）。

- [ ] **Step 4: 補交接標頭**

在 `.planning/codebase/HANDOFF.md` 寫入（以實際內容填寫五個標頭，各 2–5 行）：`目標 / 已決定 / 未決定 / 下一步 / 關鍵檔案路徑`。「關鍵檔案路徑」必須列出至少：`Taipei-City-Dashboard-BE/app/routes/router.go`、`Taipei-City-Dashboard-BE/global/global.go`、`Taipei-City-Dashboard-FE/src/store/mapStore.js`、`Taipei-City-Dashboard-FE/vite.config.js`、`docker/docker-compose.yaml`。

- [ ] **Step 5: Commit**

```bash
cd ~/Taipei-City-Dashboard
git add .planning
git diff --cached | grep -qF "$(tr -d '[:space:]' < ~/Taipei-City-Dashboard/mapbox-key.txt)" && { echo "SECRET IN DIFF"; exit 1; } || true
git commit -m "docs: add GSD codebase map

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Phase 1 部署決策（gstack）

**Files:**
- Create: `docs/decisions/0001-phase1-deploy-approach.md`

**Interfaces:**
- Consumes: `.planning/codebase/HANDOFF.md`（Task 3）、本計畫。
- Produces: 決策記錄，五個標頭；Task 5–8 依其「已決定」與「未決定」執行。

- [ ] **Step 1: 以 gstack 審本計畫**

在 Claude session 執行 `/plan-eng-review`，輸入：「審查 `docs/superpowers/plans/2026-10-06-phase1-local-deploy.md` 的 Phase 1 部署做法。重點：BE image 首次 build 會下載語言模型（`Dockerfile` 的 `model_export` 階段）的時間與失敗備案；沒有專用 health 端點時的就緒判斷；nginx 掛載 `docker/nginx/ssl` 造成的 repo 內空目錄；init 容器重跑的冪等性；3D 建物與行政區圖層因資料不可得的已知差異。」
Expected: 審查意見；若有 HIGH 問題，回頭修正本計畫對應 Task 後再繼續。

- [ ] **Step 2: 寫決策記錄**

建立 `docs/decisions/0001-phase1-deploy-approach.md`，內容以審查結論填寫，固定五個標頭：

```markdown
# 0001 Phase 1 部署做法

## 目標
（1–2 句）

## 已決定
（至少涵蓋：採官方 Docker 全容器；AI 功能停用；3D 建物與行政區圖層為已知差異；BE 就緒判斷方式；若 model_export 失敗的備案）

## 未決定
（留給實測後決定的項目）

## 下一步
Task 5 → Task 9

## 關鍵檔案路徑
docker/docker-compose.yaml、docker/docker-compose-db.yaml、docker/docker-compose-init.yaml、docker/.env.template、Taipei-City-Dashboard-BE/Dockerfile
```

- [ ] **Step 3: 驗收**

Run: `cd ~/Taipei-City-Dashboard && for h in 目標 已決定 未決定 下一步 關鍵檔案路徑; do grep -q "^## $h" docs/decisions/0001-phase1-deploy-approach.md && echo "ok $h" || echo "MISSING $h"; done`
Expected: 五行皆 `ok`。

- [ ] **Step 4: Commit**

```bash
cd ~/Taipei-City-Dashboard
git add docs/decisions/0001-phase1-deploy-approach.md
git commit -m "docs: record Phase 1 deployment decision

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `make-env.sh`（worktree、TDD）

**Files:**
- Create: `docs/agent-workflow/make-env.sh`
- Test: `docs/agent-workflow/test-make-env.sh`

**Interfaces:**
- Produces: `make-env.sh`：環境變數 `ENV_OUT`（預設 `<主 checkout>/docker/.env`）、`TOKEN_FILE`（預設 `<主 checkout>/mapbox-key.txt`）、`TEMPLATE`（預設本腳本所在 repo 的 `docker/.env.template`）。行為：不覆寫既有檔（exit 非 0）；寫入檔案權限 600；以 `secrets.token_hex` 產生 `JWT_SECRET`、`IDNO_SALT`、`DB_DASHBOARD_PASSWORD`、`DB_MANAGER_PASSWORD`、`DASHBOARD_DEFAULT_PASSWORD`、`PGADMIN_DEFAULT_PASSWORD`、`QDRANT_API_KEY`；token 檔缺少或為空時 stderr 警告含 `mapbox` 字樣但不失敗；模板缺少任何預期鍵時 exit 非 0、stderr 列出缺的鍵、且不建立檔案；stdout/stderr 永不出現任何祕密值。

- [ ] **Step 1: 建 worktree**

```bash
cd ~/Taipei-City-Dashboard
mkdir -p ~/Taipei-City-Dashboard-worktrees
git worktree add ~/Taipei-City-Dashboard-worktrees/make-env -b feature/make-env develop
cd ~/Taipei-City-Dashboard-worktrees/make-env && git branch --show-current
```
Expected: 印出 `feature/make-env`。（若此 task 由 Kandev 的 `exec-worktree` 啟動，Kandev 會自建 worktree，略過此步，改在其 worktree 內進行。）

- [ ] **Step 2: 寫失敗的測試**

在 worktree 內建立 `docs/agent-workflow/test-make-env.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SENTINEL="pk.TESTSENTINEL0123456789"
printf '%s\n  \n' "$SENTINEL" > "$TMP/token.txt"     # trailing newline + whitespace line
fail(){ echo "FAIL: $*" >&2; exit 1; }

# 1. generates file, mode 600, token injected (whitespace stripped), nothing leaked
OUT="$(ENV_OUT="$TMP/.env" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" 2>&1)"
[ -f "$TMP/.env" ] || fail "env file not created"
MODE="$(stat -f %Lp "$TMP/.env" 2>/dev/null || stat -c %a "$TMP/.env")"
[ "$MODE" = "600" ] || fail "mode is $MODE, want 600"
grep -qx "VITE_MAPBOXTOKEN=$SENTINEL" "$TMP/.env" || fail "token not injected exactly"
if printf '%s' "$OUT" | grep -q "$SENTINEL"; then fail "token leaked to output"; fi

# 2. required secrets are non-empty and not leaked
for k in JWT_SECRET IDNO_SALT DB_DASHBOARD_PASSWORD DB_MANAGER_PASSWORD DASHBOARD_DEFAULT_PASSWORD PGADMIN_DEFAULT_PASSWORD QDRANT_API_KEY; do
  v="$(grep "^$k=" "$TMP/.env" | cut -d= -f2-)"
  [ -n "$v" ] || fail "$k empty"
  if printf '%s' "$OUT" | grep -q "$v"; then fail "$k value leaked"; fi
done

# 3. refuses to overwrite
if ENV_OUT="$TMP/.env" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" >/dev/null 2>&1; then fail "overwrote existing env"; fi

# 4. missing token file: still generates, warns about mapbox, token empty
ENV_OUT="$TMP/.env2" TOKEN_FILE="$TMP/none.txt" "$HERE/make-env.sh" >/dev/null 2>"$TMP/err" || fail "missing token must not fail"
grep -qx 'VITE_MAPBOXTOKEN=' "$TMP/.env2" || fail "token should be empty"
grep -qi 'mapbox' "$TMP/err" || fail "no mapbox warning"

# 5. empty token file behaves like missing
: > "$TMP/empty.txt"
ENV_OUT="$TMP/.env3" TOKEN_FILE="$TMP/empty.txt" "$HERE/make-env.sh" >/dev/null 2>"$TMP/err3" || fail "empty token must not fail"
grep -qi 'mapbox' "$TMP/err3" || fail "no mapbox warning for empty file"

# 6. secrets differ between runs
a="$(grep '^JWT_SECRET=' "$TMP/.env")"; b="$(grep '^JWT_SECRET=' "$TMP/.env2")"
[ "$a" != "$b" ] || fail "secrets not random"

# 7. fails loudly (and creates nothing) when the template lacks expected keys
printf 'FOO=bar\n' > "$TMP/bad.template"
if TEMPLATE="$TMP/bad.template" ENV_OUT="$TMP/.env4" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" >/dev/null 2>"$TMP/err4"; then fail "must fail when template lacks expected keys"; fi
grep -q 'JWT_SECRET' "$TMP/err4" || fail "error must name the missing key"
[ ! -e "$TMP/.env4" ] || fail "must not create env file when keys are missing"

# 8. the real upstream template contains every expected key
ENV_OUT="$TMP/.env5" TOKEN_FILE="$TMP/token.txt" "$HERE/make-env.sh" >/dev/null 2>&1 || fail "real docker/.env.template lacks an expected key"
echo PASS
```

- [ ] **Step 3: 執行確認失敗**

Run: `cd ~/Taipei-City-Dashboard-worktrees/make-env && bash docs/agent-workflow/test-make-env.sh`
Expected: FAIL（`make-env.sh: No such file or directory`）

- [ ] **Step 4: 寫最小實作**

建立 `docs/agent-workflow/make-env.sh`：

```bash
#!/usr/bin/env bash
# Generate a local-only docker/.env from docker/.env.template.
# Secrets are generated here and never printed.
set -euo pipefail

SELF_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMON_ROOT="$(dirname "$(git -C "$SELF_ROOT" rev-parse --path-format=absolute --git-common-dir)")"
export TEMPLATE="${TEMPLATE:-$SELF_ROOT/docker/.env.template}"
export ENV_OUT="${ENV_OUT:-$COMMON_ROOT/docker/.env}"
export TOKEN_FILE="${TOKEN_FILE:-$COMMON_ROOT/mapbox-key.txt}"

python3 - <<'PY'
import os, re, secrets, sys

tpl, out, tok = os.environ["TEMPLATE"], os.environ["ENV_OUT"], os.environ["TOKEN_FILE"]
if os.path.exists(out):
    sys.exit(f"refusing to overwrite existing {out}")

token = ""
if os.path.exists(tok):
    token = "".join(open(tok).read().split())
if not token:
    print(f"warning: no Mapbox token found at {tok}; VITE_MAPBOXTOKEN left empty (map will not render)", file=sys.stderr)

rnd = lambda n=12: secrets.token_hex(n)
values = {
    "NODE_ENV": "development",
    "VITE_MAPBOXTOKEN": token,
    "JWT_SECRET": rnd(), "IDNO_SALT": rnd(),
    "DASHBOARD_DEFAULT_USERNAME": "admin",
    "DASHBOARD_DEFAULT_Email": "admin@example.com",
    "DASHBOARD_DEFAULT_PASSWORD": rnd(8),
    "DB_DASHBOARD_PASSWORD": rnd(), "DB_MANAGER_PASSWORD": rnd(),
    "PGADMIN_DEFAULT_EMAIL": "pgadmin@example.com", "PGADMIN_DEFAULT_PASSWORD": rnd(8),
    "QDRANT_API_KEY": rnd(),
}

lines, touched = [], []
for line in open(tpl).read().splitlines():
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
    if m and m.group(1) in values:
        line = f"{m.group(1)}={values[m.group(1)]}"
        touched.append(m.group(1))
    lines.append(line)

missing = sorted(set(values) - set(touched))
if missing:
    sys.exit("template is missing expected keys: " + ", ".join(missing))

os.makedirs(os.path.dirname(out), exist_ok=True)
fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"wrote {out} (mode 600); set: {', '.join(touched)}")
PY
```

- [ ] **Step 5: 加執行權限並跑測試確認通過**

Run: `cd ~/Taipei-City-Dashboard-worktrees/make-env && chmod +x docs/agent-workflow/make-env.sh docs/agent-workflow/test-make-env.sh && bash docs/agent-workflow/test-make-env.sh`
Expected: `PASS`

- [ ] **Step 6: 以 gstack `/review` 審 diff**

在 worktree 的 Claude session 執行 `/review`。Expected: 無 HIGH 問題；若有，修正並重跑 Step 5。

- [ ] **Step 7: 檢查無祕密後 commit（在 worktree）**

```bash
cd ~/Taipei-City-Dashboard-worktrees/make-env
git add -f docs/agent-workflow/make-env.sh docs/agent-workflow/test-make-env.sh   # upstream .gitignore has '*.sh'
git diff --cached | grep -qF "$(tr -d '[:space:]' < ~/Taipei-City-Dashboard/mapbox-key.txt)" && { echo "SECRET IN DIFF"; exit 1; } || true
git commit -m "feat: add local docker env generator with tests

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: 經使用者在 Merge-ready 核准後，本機合併**

```bash
cd ~/Taipei-City-Dashboard
git checkout develop
git merge --no-ff feature/make-env -m "merge: make-env generator"
bash docs/agent-workflow/test-make-env.sh
```
Expected: 合併後在 `develop` 上測試仍 `PASS`。接著清理：`git worktree remove ~/Taipei-City-Dashboard-worktrees/make-env && git branch -d feature/make-env`（`-d` 成功代表已完整合併）。

---

### Task 6: 預檢與起基礎設施（DB / Redis / Qdrant）

**Files:** 無新增被追蹤檔案（只產生被忽略的 `docker/.env`、建立 docker 網路與容器）。

**Interfaces:**
- Consumes: `make-env.sh`（Task 5，已合併到 `develop`）。
- Produces: `docker/.env`（權限 600、被 `.gitignore` 忽略）；docker 網路 `br_dashboard`；運行中的 `redis`、`postgres-data`、`postgres-manager`、`qdrant`。

- [ ] **Step 1: 在整合 checkout 產生 `docker/.env`**

```bash
cd ~/Taipei-City-Dashboard
bash docs/agent-workflow/make-env.sh
stat -f %Lp docker/.env
git status -s
```
Expected: 第一個指令印 `wrote .../docker/.env (mode 600); set: ...`（沒有任何祕密值）；`stat` 印 `600`；`git status` 不顯示 `docker/.env`。

- [ ] **Step 2: 確認 Docker 可用與資源**

```bash
docker info --format 'MemTotal={{.MemTotal}} NCPU={{.NCPU}}'
```
Expected: 可正常輸出（記憶體約 8.3 GB 屬已知限制，見決策記錄；不足時由使用者在 Docker Desktop 調高，這步只記錄）。

- [ ] **Step 3: 建 docker 網路（先確認不衝突）**

```bash
docker network ls --format '{{.Name}}' | grep -x br_dashboard && echo "network exists" || {
  docker network ls -q | xargs docker network inspect --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' | tr ' ' '\n' | grep -x '192.168.128.0/24' && { echo "SUBNET CONFLICT"; exit 1; }
  docker network create --driver=bridge --subnet=192.168.128.0/24 --gateway=192.168.128.1 br_dashboard
}
```
Expected: 印出新網路 ID，或 `network exists`。若印 `SUBNET CONFLICT`，改用 `192.168.129.0/24` / `192.168.129.1` 重建，並在 `MEMORY.md` 記錄（網路名稱 `br_dashboard` 不可變，compose 以 `external: true` 引用）。

- [ ] **Step 4: 埠號預檢（只回報，不殺任何行程）**

```bash
busy=0; for p in 8080 8088 5432 6333 6334; do
  who="$(lsof -nP -iTCP:$p -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1" (pid "$2")"}')"
  [ -n "$who" ] && { echo "port $p busy -> $who"; busy=1; }
done; [ "$busy" = 0 ] && echo "PORTS OK"
```
Expected: `PORTS OK`。若有任何 `port N busy -> ...`，**停止**並把占用者回報給使用者決定，不得自行關閉行程。

- [ ] **Step 5: 啟動基礎設施（只起需要的四個服務）**

```bash
cd ~/Taipei-City-Dashboard/docker
docker compose -f docker-compose-db.yaml up -d redis postgres-data postgres-manager qdrant
docker compose -f docker-compose-db.yaml ps
```
Expected: 四個服務皆為 `running`。（不啟動 pgAdmin，見決策記錄 ruling 4。）

- [ ] **Step 6: 驗證 DB 與 Redis 可連線**

```bash
for c in postgres-data postgres-manager; do
  for i in $(seq 1 30); do docker exec $c pg_isready -U postgres >/dev/null 2>&1 && break; sleep 2; done
  docker exec $c pg_isready -U postgres
done
docker exec redis redis-cli ping
```
Expected: 兩行 `... - accepting connections` 與 `PONG`。

---

### Task 7: 初始化資料庫與前端相依

**Files:** 無（只操作容器與 DB；不產生被追蹤的變更）

**Interfaces:**
- Consumes: `docker/.env`（Task 6）、兩個運行中的 PostGIS（Task 6）。
- Produces: `dashboard` 與 `dashboardmanager` 兩個資料庫已 migrate 並載入示範資料；`Taipei-City-Dashboard-FE/node_modules` 已安裝。

- [ ] **Step 1: 執行初始化**

```bash
cd ~/Taipei-City-Dashboard/docker
docker compose -f docker-compose-init.yaml up 2>&1 | tail -40
```
Expected: 三個容器 `dashboard-fe-init`、`dashboard-be-init-manager`、`dashboard-be-init-dashboard` 皆結束。第一次會下載 Go 模組與 npm 套件，需數分鐘。

- [ ] **Step 2: 確認三個 init 容器已結束（exit 0 只是必要條件，不是成功證明）**

Run: `docker ps -a --filter name=dashboard-fe-init --filter name=dashboard-be-init --format '{{.Names}} {{.Status}}'`
Expected: 三行皆含 `Exited (0)`。非 0 時用 `docker logs <name> | tail -50` 找原因並修正。**注意**：`app/initial/initial.go` 會吞掉錯誤、`psql -f` 沒有 `ON_ERROR_STOP`，所以即使資料沒載入也會 `Exited (0)`；真正的驗收是下面的資料列數。

- [ ] **Step 3: 驗收資料表與資料列數（以此為準）**

```bash
set -a; . ./.env; set +a
docker exec postgres-data psql -U "$DB_DASHBOARD_USER" -d "$DB_DASHBOARD_DBNAME" -tAc "select count(*) from information_schema.tables where table_schema='public'"
docker exec postgres-data psql -U "$DB_DASHBOARD_USER" -d "$DB_DASHBOARD_DBNAME" -tAc "select relname, n_live_tup from pg_stat_user_tables order by n_live_tup desc limit 5"
docker exec postgres-manager psql -U "$DB_MANAGER_USER" -d "$DB_MANAGER_DBNAME" -tAc "select count(*) from information_schema.tables where table_schema='public'"
```
Expected: 兩個資料表數量都 > 0，且 dashboard 資料庫最大的幾張表 `n_live_tup` > 0（示範資料約 1.6 萬行 SQL，`db-sample-data/dashboard-demo.sql`）。若表存在但列數為 0，表示載入靜默失敗：不要重跑，改走 Step 5 的重置。

- [ ] **Step 4: 確認有預設管理員**

```bash
docker exec postgres-manager psql -U "$DB_MANAGER_USER" -d "$DB_MANAGER_DBNAME" -tAc "select count(*) from auth_users"
```
Expected: ≥ 1。（表名不是 `auth_users` 時，用 `\dt` 列出後依實際名稱重查，並把實際名稱記入證據檔。）

- [ ] **Step 5: 不重跑；記錄重置方法**

初始化是一次性動作：`migrateDB` 用 GORM `AutoMigrate`（可重跑），但 `initDashboard` 以 `psql -f` 灌入示範資料，重跑可能重複寫入或靜默出錯（見決策記錄 A9）。**不要為了觀察而重跑。** 需要重做時（僅限本機示範資料）：

```bash
cd ~/Taipei-City-Dashboard/docker
docker compose -f docker-compose-db.yaml down
docker volume rm postgres_data postgres_manager_data
docker compose -f docker-compose-db.yaml up -d redis postgres-data postgres-manager qdrant
```
把這段指令與結論寫進 `docs/agent-workflow/evidence/phase1-verification.md` 的「重跑行為」一節（Task 9 建立）。刪 volume 屬破壞性操作，只在 Step 3 失敗且使用者確認後才執行。

---

### Task 8: 起應用（FE / BE）

**Files:** 無被追蹤的變更預期。

**Interfaces:**
- Consumes: `docker/.env`、已初始化的 DB。
- Produces: 運行中的 `dashboard-fe`（主機 8080）與 `dashboard-be`（主機 8088）。不啟動 nginx、`vector-db-upgrade`、pgAdmin（決策記錄 ruling 3、4）。

- [ ] **Step 1: 先單獨建置 BE image（失敗不留下半啟動的堆疊）**

```bash
cd ~/Taipei-City-Dashboard/docker
time docker compose -f docker-compose.yaml build dashboard-be 2>&1 | tail -30
```
Expected: 建置成功。首次會跑 `model_export`（pip 安裝 + 下載 Hugging Face 的 `intfloat/multilingual-e5-base` 並轉 ONNX）與下載 onnxruntime，**預估 10–30 分鐘（未驗證）**，把實際耗時記入證據檔。失敗時：先原樣重試（已完成的層有快取）；若是 Hugging Face 速率限制，請使用者提供自己的 HF token，以 `docker compose -f docker-compose.yaml build --build-arg HF_TOKEN=... dashboard-be` 重試（token 不得進對話輸出或 commit）。**沒有**「純 golang image」備案：BE 缺模型會 `log.Fatalf`（`app/app.go:47`）。

- [ ] **Step 2: 啟動 FE 與 BE**

```bash
docker compose -f docker-compose.yaml up -d dashboard-fe dashboard-be
docker ps --format '{{.Names}} {{.Status}}' | sort
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}'
```
Expected: `dashboard-be`、`dashboard-fe` 為 `Up`；`docker stats` 的記憶體數字記入證據檔（Docker 只配約 8.3 GB）。

- [ ] **Step 3: 等待 BE 就緒（注意結尾斜線）**

```bash
for i in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8088/api/v1/dashboard/ || true)"
  [ "$code" = "200" ] && break; sleep 5
done
echo "BE /api/v1/dashboard/ -> $code"
docker logs dashboard-be 2>&1 | grep -c 'Listening and serving HTTP'
docker logs dashboard-be 2>&1 | tail -15
```
Expected: `200`，且 log 含 `Listening and serving HTTP`。路由是 `GET("/", ...)`（`router.go:137`），不帶結尾斜線會得到 301。若不是 200：BE 沒有專用 health 端點，依 `docker logs` 判斷（是否有 `Fatalf`、資料庫或 Redis 連線錯誤），並把實際回應碼記入證據檔。該路由有 `LimitAPIRequests` 限流，若看到 429 就拉長輪詢間隔並記錄。

- [ ] **Step 4: 確認 repo 乾淨**

Run: `cd ~/Taipei-City-Dashboard && git status -s`
Expected: 無輸出（`docker/.env`、`mapbox-key.txt`、`node_modules` 皆被忽略）。

- [ ] **Step 5: 確認前端回應**

```bash
curl -s -o /dev/null -w 'FE %{http_code}\n' http://localhost:8080/
curl -s http://localhost:8080/ | grep -o '<title>[^<]*</title>'
```
Expected: `FE 200` 與標題含「臺北城市儀表板」（來自 `VITE_APP_TITLE`）。

---

### Task 9: 驗收與證據

**Files:**
- Create: `docs/agent-workflow/evidence/phase1-verification.md`

**Interfaces:**
- Consumes: Task 6–8 的運行狀態。
- Produces: 逐項驗收證據檔（不含祕密），供 Task 10 與 Phase 2 計畫引用。

- [ ] **Step 1: 逐項取證**

在 `docs/agent-workflow/evidence/phase1-verification.md` 依序記錄（每項貼上**實際指令輸出**，禁止憑印象）：

1. FE：`curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/` → 200。
2. BE：`curl -s -o /dev/null -w '%{http_code}' http://localhost:8088/api/v1/dashboard/` → 實際回應碼。
3. 兩個 DB 的資料表數量與關鍵表資料列數（Task 7 Step 3 輸出）。
4. 預設管理員存在（Task 7 Step 4 輸出）。
5. 重跑行為：靜態結論與重置指令（決策記錄 A9；不實測）。
6. 容器清單、`docker stats` 記憶體、`docker image ls --digests`（Task 8 Step 2；記錄 `latest` 映像的 digest）。
7. 已知差異：3D 建物圖層（`VITE_MAPBOXTILE` 留空）與行政區邊界（`/geo_server/...` 示範環境沒有）。

- [ ] **Step 2: 瀏覽器驗收（gstack QA 原則：只觀察、不修、附證據）**

用 Playwright（`NODE_PATH=~/gstack/node_modules`）執行 `docs/agent-workflow/evidence/qa/qa-probe.js`：對 `http://localhost:8080/dashboard`、`/mapview`、`/admin` 取得 console 錯誤、失敗請求、DOM 事實與截圖，並實際看截圖確認圖表與底圖有渲染。3D 建物與行政區圖層的錯誤屬預期。管理員登入：`docker/.env` 受祕密讀取防護保護，代理不得讀取；標為「未驗證」並交由使用者自行登入。
Expected: 每頁在證據檔標 `PASS` 或 `FAIL（原因）`。

- [ ] **Step 3: 驗證證據檔沒有祕密（不讀取 `docker/.env`）**

```bash
cd ~/Taipei-City-Dashboard
T="$(tr -d '[:space:]' < mapbox-key.txt)"
grep -rlF "$T" docs/ MEMORY.md CLAUDE.md AGENTS.md .planning && { echo "TOKEN LEAK"; exit 1; } || echo "no Mapbox token in tracked docs"
grep -rnE '\b([0-9a-f]{16}|[0-9a-f]{24})\b' docs/agent-workflow/evidence MEMORY.md CLAUDE.md AGENTS.md | grep -v probe-results.json && { echo "POSSIBLE GENERATED SECRET"; exit 1; } || echo "no generated-secret-shaped strings"
```
Expected: 兩行 `no ...`。（`make-env.sh` 產生的密碼為 16 或 24 位十六進位字串，故用樣式掃描。）

- [ ] **Step 4: Commit（文件類）**

```bash
git add docs/agent-workflow/evidence
git diff --cached --stat
git commit -m "docs: record Phase 1 verification evidence

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 10: 收尾、學習與交接

**Files:**
- Modify: `MEMORY.md`
- Create: `.planning/` 的 phase 交接（由 GSD 技能產生）

**Interfaces:**
- Consumes: Task 9 證據檔。
- Produces: 更新後的 `MEMORY.md`；Phase 1 結論與 Phase 2 前置資訊，供下一份計畫使用。

- [ ] **Step 1: 萃取學習**

在 Claude session 執行 `gsd-extract-learnings`，輸入：「Phase 1：本地部署。來源：`docs/agent-workflow/evidence/phase1-verification.md`、`docs/decisions/0001-phase1-deploy-approach.md`。」
Expected: 產出決策/教訓/意外清單。

- [ ] **Step 2: 更新 `MEMORY.md`**

把「目前狀態」改為 Phase 1 結果（一行），並加入索引條目（每條一行，細節放連結檔）：
- 驗收證據：`docs/agent-workflow/evidence/phase1-verification.md`
- 決策：`docs/decisions/0001-phase1-deploy-approach.md`
- 踩坑（實測得到的，例如 BE build 時間、`docker/nginx/ssl` 處理、init 重跑行為、Kandev task 前綴）
- 已知差異：3D 建物與行政區圖層
- Phase 2 的開放問題（列出，供下一份計畫處理）

- [ ] **Step 3: 驗證文件三件組仍合格**

Run: `cd ~/Taipei-City-Dashboard && bash docs/agent-workflow/check-docs.sh`
Expected: `PASS`

- [ ] **Step 4: 確認 worktree 已清理**

Run: `cd ~/Taipei-City-Dashboard && git worktree list && git branch --list 'feature/*'`
Expected: 只有主 checkout；沒有殘留的 `feature/*` 分支（Task 5 Step 8 已清理）。

- [ ] **Step 5: 暫停交接（GSD）**

執行 `gsd-pause-work`，確認 `.planning/` 寫入交接。

- [ ] **Step 6: 最終 commit 與狀態回報**

```bash
cd ~/Taipei-City-Dashboard
git add MEMORY.md .planning
git diff --cached | grep -qF "$(tr -d '[:space:]' < ~/Taipei-City-Dashboard/mapbox-key.txt)" && { echo "SECRET IN DIFF"; exit 1; } || true
git commit -m "docs: wrap up Phase 1 and hand off to Phase 2

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
git log --oneline | head -12
git status -s
```
Expected: 工作區乾淨；log 可見本計畫每個 Task 的 commit。向使用者回報 Phase 1 結果（逐項 PASS/FAIL）並提出 Phase 2 計畫的邀請。

---

## Self-Review

**Spec coverage**
- §1 成功標準 1（FE/BE/DB/管理後台）→ Task 7、8、9；標準 2（Phase 2 熱重載）→ 明確延後到下一份計畫（範圍說明）；標準 3（worktree 紀律）→ Task 5、6 實際演練；標準 4（新 session 只讀 CLAUDE.md）→ Task 2、3。
- §2 三層分工 → Task 3（GSD）、Task 4（gstack）、Task 5（superpowers TDD）、Task 9（gstack `/qa-only` + superpowers 驗證）、Task 10（GSD 收尾）。
- §3 Kandev → Task 1。
- §4 分支紀律 → Global Constraints、Task 5/6。
- §5 context 與交接 → Task 2、3、10。
- §6 Phase 1 task 序列 TCD-1…8 → Task 1–10 對應（clone 已由使用者完成並以 `80b1c3ec` 提交 spec）。
- §9.1 地圖 α → Task 5（token 注入）、Task 9（底圖驗收與已知差異）。
- 選配 TCD-B1（MapLibre）留給 Phase 2 計畫。
- Phase 2（§7）未涵蓋，已在範圍說明明確延後。

**Placeholder scan**：所有程式碼步驟皆附完整程式碼；Task 3、4 的內容由技能產出（無法預先寫死），已給出精確指令、輸入與機器可驗的驗收指令。Task 4 Step 2 的文件骨架中「（…）」是由審查結論填寫的內容區，驗收腳本檢查標頭存在。

**型別/名稱一致性**：`WS_NAME`、`COLUMNS`、`WORKFLOWS`、`SEED_TASKS`、`call`、`main` 在 bootstrap 與測試間一致；`ENV_OUT`、`TOKEN_FILE`、`TEMPLATE`、`PORTS`、`SKIP_DOCKER` 在腳本與測試間一致；種子 task 標題 `P1-01…P1-08` 與 MEMORY.md、Task 對應一致。

**已知不確定（誠實標示）**：Kandev `POST /tasks` 的 `executor_id` 與 `repositories` 實際接受度、`stage_type: "custom"` 是否為合法值（觀察到現有 workflow 使用 `custom`）、Kandev 是否自動附帶 `Kanban` workflow，皆在 Task 1 Step 4 以實機回應驗證，錯誤訊息會直接指出欄位問題。
