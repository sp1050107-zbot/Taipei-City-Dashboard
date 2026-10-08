#!/usr/bin/env python3
"""Create the Kandev workspace, repository, workflows, steps, seed tasks and the .scratch ticket cards. Idempotent by key."""
import glob
import json
import os
import re
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
     "desc": f"計畫 Task 2（{PLAN}）。完成條件：bash docs/agent-workflow/check-docs.sh 輸出 PASS，且已 commit 到 develop。"},
    {"title": "P1-02 程式碼地圖（GSD）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 3（{PLAN}）。技能：gsd-map-codebase。交接檔：CLAUDE.md。完成條件：.planning/codebase/ 至少 4 份文件並 commit。"},
    {"title": "P1-03 Phase 1 部署決策（gstack）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 4（{PLAN}）。技能：/plan-eng-review。交接檔：.planning/codebase/ 與該計畫。完成條件：docs/decisions/0001-phase1-deploy-approach.md 含五個標頭並 commit。"},
    {"title": "P1-04 make-env.sh（worktree）", "exec": EXEC_WORKTREE,
     "desc": f"計畫 Task 5（{PLAN}）。技能：superpowers:test-driven-development。完成條件：test-make-env.sh 輸出 PASS，審查通過，經使用者核准後本機 merge 回 develop。"},
    {"title": "P1-05 起基礎設施（DB/Redis/Qdrant）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 6（{PLAN}）。完成條件：四個容器運行（redis、postgres-data、postgres-manager、qdrant），兩個 PostGIS 可連線。"},
    {"title": "P1-06 初始化資料庫與前端相依", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 7（{PLAN}）。完成條件：三個 init 容器 exit 0 且資料列數 > 0（exit 0 不是成功證明；init 不重跑）。"},
    {"title": "P1-07 起應用（FE/BE）", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 8（{PLAN}）。完成條件：FE:8080 回 200，BE /api/v1/dashboard/（帶結尾斜線）回 200，git status 乾淨。BE 啟動需要本地嵌入模型（model_export 為必經）；首次 build 預留 1 小時以上。"},
    {"title": "P1-08 驗收與收尾", "exec": EXEC_LOCAL,
     "desc": f"計畫 Task 9、10（{PLAN}）。技能：/qa-only、verification-before-completion、gsd-extract-learnings。完成條件：docs/agent-workflow/evidence/phase1-verification.md 逐項有證據，MEMORY.md 已更新。"},
]


# Ticket cards: every .scratch/<feature>/issues/<NN>-<slug>.md has exactly one Kandev card whose
# description is only the file path (the file is the source of truth; Kandev is the owner's progress view).
FEATURE_PREFIX = {"phase2-hybrid-dev": "P2"}   # unknown features use their own slug as the key prefix
TICKET_WORKFLOW = "B 客製開發"
STATUS_COLUMN = {
    "ready-for-agent": "Backlog",
    "needs-triage": "Backlog",
    "needs-info": "Backlog",
    "claimed": "Build (worktree)",
    "ready-for-human": "Merge-ready",
    "resolved": "Done",
    "wontfix": "Done",
}


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
    except urllib.error.URLError as e:
        raise SystemExit(f"{method} {path} -> cannot reach Kandev at {BASE} ({e.reason}). Is Kandev running?")


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
    existing = {s["name"]: s for s in (call("GET", f"/workflows/{wf_id}/workflow/steps")["steps"] or [])}
    for pos, col in enumerate(COLUMNS):
        if col["name"] in existing:
            continue
        call("POST", "/workflow/steps", {
            "workflow_id": wf_id, "name": col["name"], "position": pos, "color": col["color"],
            "prompt": col["prompt"], "allow_manual_move": True, "is_start_step": pos == 0,
            "stage_type": "custom", "complete_task_on_enter": bool(col.get("done")),
        })
    return {s["name"]: s for s in (call("GET", f"/workflows/{wf_id}/workflow/steps")["steps"] or [])}


def ensure_tasks(ws_id, wf_id, backlog_id, repo_id):
    """Upsert the seed tasks by their P1-xx key: create missing ones, update stale title/description."""
    have = {t["title"].split(" ")[0]: t for t in call("GET", f"/workspaces/{ws_id}/tasks")["tasks"]}
    for t in SEED_TASKS:
        key = t["title"].split(" ")[0]
        cur = have.get(key)
        if cur is None:
            call("POST", "/tasks", {
                "workspace_id": ws_id, "workflow_id": wf_id, "workflow_step_id": backlog_id,
                "title": t["title"], "description": t["desc"], "executor_id": t["exec"],
                "repositories": [{"repository_id": repo_id, "base_branch": "develop"}],
            })
        elif cur["title"] != t["title"] or cur.get("description") != t["desc"]:
            call("PATCH", f"/tasks/{cur['id']}", {"title": t["title"], "description": t["desc"]})


def column_for(status, has_answer):
    """Kandev column for a ticket Status. A claimed ticket that already has an Answer awaits acceptance."""
    if status == "claimed" and has_answer:
        return "Verify"
    return STATUS_COLUMN.get(status, "Backlog")


def ticket_cards(root=REPO_PATH):
    """Read every .scratch/*/issues/NN-slug.md under root and describe its card."""
    cards = []
    for path in sorted(glob.glob(os.path.join(root, ".scratch", "*", "issues", "[0-9][0-9]-*.md"))):
        text = open(path, encoding="utf-8").read()
        head = re.match(r"#\s*(\d+):\s*(.+)", text)
        status = re.search(r"^\**Status:\**\s*(\S+)", text, re.M)
        if not head or not status:
            continue
        feature = os.path.basename(os.path.dirname(os.path.dirname(path)))
        num = int(head.group(1))
        key = f"{FEATURE_PREFIX.get(feature, feature)}-{num:02d}"
        cards.append({
            "key": key,
            "title": f"{key} {head.group(2).strip()}",
            "desc": os.path.relpath(path, root),
            "column": column_for(status.group(1), "\n## Answer" in text),
        })
    return cards


def sync_ticket_cards(ws_id, wf_id, steps, repo_id, root=REPO_PATH):
    """Upsert one card per ticket and move it to the column its Status maps to. Idempotent."""
    have = {t["title"].split(" ")[0]: t for t in call("GET", f"/workspaces/{ws_id}/tasks")["tasks"]}
    for c in ticket_cards(root):
        target = steps[c["column"]]["id"]
        cur = have.get(c["key"])
        if cur is None:
            cur = call("POST", "/tasks", {
                "workspace_id": ws_id, "workflow_id": wf_id, "workflow_step_id": steps["Backlog"]["id"],
                "title": c["title"], "description": c["desc"], "executor_id": EXEC_LOCAL,
                "repositories": [{"repository_id": repo_id, "base_branch": "develop"}],
            })
        elif cur["title"] != c["title"] or cur.get("description") != c["desc"]:
            call("PATCH", f"/tasks/{cur['id']}", {"title": c["title"], "description": c["desc"]})
        if cur.get("workflow_step_id") != target:
            call("POST", f"/tasks/{cur['id']}/move", {"workflow_id": wf_id, "workflow_step_id": target, "position": 0})


def main():
    ws = ensure_workspace()
    repo = ensure_repo(ws["id"])
    wf_ids = {}
    for name, desc in WORKFLOWS.items():
        wf = ensure_workflow(ws["id"], name, desc)
        steps = ensure_steps(wf["id"])
        wf_ids[name] = (wf["id"], steps["Backlog"]["id"], steps)
    wf_a, backlog_a, _ = wf_ids["A 部署與研究"]
    ensure_tasks(ws["id"], wf_a, backlog_a, repo["id"])
    wf_b, _, steps_b = wf_ids[TICKET_WORKFLOW]
    sync_ticket_cards(ws["id"], wf_b, steps_b, repo["id"])
    print(f"workspace={ws['id']} repo={repo['id']} workflows={len(wf_ids)}")


if __name__ == "__main__":
    main()
