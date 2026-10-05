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
