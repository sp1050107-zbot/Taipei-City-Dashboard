#!/usr/bin/env python3
"""Verifies the live Kandev state created by kandev_bootstrap.py."""
import sys, os
import urllib.error
from unittest.mock import patch
sys.path.insert(0, os.path.dirname(__file__))
import tempfile, pathlib
from kandev_bootstrap import call, main, WS_NAME, COLUMNS, WORKFLOWS, SEED_TASKS
import kandev_bootstrap as kb


def test_unreachable_raises_friendly_error():
    """Kandev down must raise SystemExit with a clear message, not an unhandled traceback."""
    with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("Connection refused")):
        try:
            call("GET", "/workspaces")
        except SystemExit as e:
            assert "cannot reach Kandev" in str(e), f"unexpected message: {e}"
        else:
            raise AssertionError("expected SystemExit when Kandev is unreachable")


def test_archived_tasks_are_not_recreated():
    """Archived seed cards (P1-xx) are hidden from the default task list; ensure_tasks must still see them."""
    archived = [{"id": f"id-{t['title'].split(' ')[0]}", "title": t["title"], "description": t["desc"]} for t in SEED_TASKS]
    posts = []

    def fake_call(method, path, body=None):
        if method == "GET" and path.endswith("/tasks?include_archived=true"):
            return {"tasks": archived}
        if method == "GET" and path.endswith("/tasks"):
            return {"tasks": []}          # the default list hides archived tasks
        posts.append((method, path))
        return {}

    with patch.object(kb, "call", fake_call):
        kb.ensure_tasks("ws", "wf", "backlog", "repo")
    assert posts == [], f"archived seed cards were recreated or patched: {posts}"


def snapshot():
    ws = [w for w in call("GET", "/workspaces")["workspaces"] if w["name"] == WS_NAME]
    assert len(ws) == 1, f"expected exactly 1 workspace named {WS_NAME}, got {len(ws)}"
    ws = ws[0]
    wfs = [w for w in call("GET", "/workflows")["workflows"] if w["workspace_id"] == ws["id"]]
    repos = call("GET", f"/workspaces/{ws['id']}/repositories")["repositories"]
    tasks = kb.list_tasks(ws["id"])   # archived cards are still part of the state
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
    by_key = {t["title"].split(" ")[0]: t for t in tasks}
    for t in SEED_TASKS:
        key = t["title"].split(" ")[0]
        assert key in by_key, f"seed task missing: {key}"
        assert by_key[key]["title"] == t["title"], f"{key}: title is stale: {by_key[key]['title']!r}"
        assert by_key[key]["description"] == t["desc"], f"{key}: description is stale"
    return len(wfs), len(repos), len(tasks)


def test_ticket_cards_live():
    """Every .scratch ticket has exactly one live card in the right column, description = path only."""
    ws, wfs, repos, tasks = snapshot()
    wf = next(w for w in wfs if w["name"] == kb.TICKET_WORKFLOW)
    steps = {s["id"]: s["name"] for s in call("GET", f"/workflows/{wf['id']}/workflow/steps")["steps"]}
    by_key = {}
    for t in tasks:
        by_key.setdefault(t["title"].split(" ")[0], []).append(t)
    cards = kb.ticket_cards()
    assert cards, "no tickets found under .scratch"
    for c in cards:
        found = by_key.get(c["key"], [])
        assert len(found) == 1, f"{c['key']}: expected exactly one card, got {len(found)}"
        t = found[0]
        assert t["title"] == c["title"], f"{c['key']}: stale title"
        assert t["description"] == c["desc"], f"{c['key']}: description must be the ticket path only"
        assert steps.get(t["workflow_step_id"]) == c["column"], f"{c['key']}: in {steps.get(t['workflow_step_id'])!r}, want {c['column']!r}"
    return len(cards)


def test_idempotent():
    before = snapshot()
    main()
    after = snapshot()
    assert (len(before[1]), len(before[2]), len(before[3])) == (len(after[1]), len(after[2]), len(after[3])), "second run created duplicates"


# ---- ticket cards: one Kandev card per .scratch ticket, description = the file path only ----

def make_ticket(root, feature, num, slug, title, status, answer=False):
    d = pathlib.Path(root) / ".scratch" / feature / "issues"
    d.mkdir(parents=True, exist_ok=True)
    body = f"# {num:02d}: {title}\n\n**What to build:** x\n\n**Blocked by:** None\n\n**Status:** {status}\n\n- [ ] a\n"
    if answer:
        body += "\n## Answer\n\ndone\n"
    f = d / f"{num:02d}-{slug}.md"
    f.write_text(body, encoding="utf-8")
    return f


def test_column_for_status():
    assert kb.column_for("ready-for-agent", False) == "Backlog"
    assert kb.column_for("claimed", False) == "Build (worktree)"
    assert kb.column_for("claimed", True) == "Verify", "claimed with an Answer is waiting for acceptance"
    assert kb.column_for("resolved", True) == "Done"
    assert kb.column_for("ready-for-human", False) == "Merge-ready"
    assert kb.column_for("wontfix", False) == "Done"
    assert kb.column_for("something-new", False) == "Backlog", "unknown statuses must not be lost"


def test_ticket_cards_parse_files():
    with tempfile.TemporaryDirectory() as root:
        make_ticket(root, "phase2-hybrid-dev", 1, "revise-plan", "Revise the plan", "resolved", True)
        make_ticket(root, "phase2-hybrid-dev", 10, "acceptance", "Acceptance", "claimed", True)
        make_ticket(root, "other-feature", 2, "thing", "Do a thing", "ready-for-agent")
        cards = {c["key"]: c for c in kb.ticket_cards(root)}
        assert set(cards) == {"P2-01", "P2-10", "other-feature-02"}, sorted(cards)
        c = cards["P2-01"]
        assert c["title"] == "P2-01 Revise the plan"
        assert c["desc"] == ".scratch/phase2-hybrid-dev/issues/01-revise-plan.md", "description must be the path only"
        assert c["column"] == "Done" and cards["P2-10"]["column"] == "Verify"
        assert cards["other-feature-02"]["column"] == "Backlog"


def test_card_titles_fit_kandev_limit():
    """Kandev rejects titles over 60 characters; the key must stay at the front and the result be stable."""
    with tempfile.TemporaryDirectory() as root:
        make_ticket(root, "phase2-hybrid-dev", 7, "long", "Close the gitignore gap for the frontend local environment file", "resolved", True)
        make_ticket(root, "phase2-hybrid-dev", 8, "short", "Short title", "resolved", True)
        cards = {c["key"]: c for c in kb.ticket_cards(root)}
        long_title = cards["P2-07"]["title"]
        assert len(long_title) <= 60, f"{len(long_title)} chars: {long_title!r}"
        assert long_title.startswith("P2-07 Close the gitignore gap"), long_title
        assert cards["P2-08"]["title"] == "P2-08 Short title"
        assert [c["title"] for c in kb.ticket_cards(root)] == [c["title"] for c in kb.ticket_cards(root)]


def test_sync_creates_moves_and_is_idempotent():
    steps = {c["name"]: {"id": "step-" + c["name"]} for c in COLUMNS}
    calls = []
    store = {}

    def fake_call(method, path, body=None):
        calls.append((method, path, body))
        if method == "GET" and path.endswith("/tasks?include_archived=true"):
            return {"tasks": list(store.values())}
        if method == "POST" and path == "/tasks":
            t = {"id": "t%d" % (len(store) + 1), "title": body["title"], "description": body["description"],
                 "workflow_step_id": body["workflow_step_id"]}
            store[t["id"]] = t
            return t
        if method == "POST" and path.endswith("/move"):
            tid = path.split("/")[2]
            store[tid]["workflow_step_id"] = body["workflow_step_id"]
            return {}
        if method == "PATCH":
            tid = path.split("/")[2]
            store[tid].update({k: v for k, v in body.items() if k in ("title", "description")})
            return {}
        raise AssertionError((method, path))

    with tempfile.TemporaryDirectory() as root:
        f = make_ticket(root, "phase2-hybrid-dev", 1, "a", "Alpha", "ready-for-agent")
        make_ticket(root, "phase2-hybrid-dev", 2, "b", "Beta", "resolved", True)
        with patch.object(kb, "call", fake_call):
            kb.sync_ticket_cards("ws", "wf", steps, "repo", root)
            assert len(store) == 2, store
            by = {t["title"].split(" ")[0]: t for t in store.values()}
            assert by["P2-01"]["workflow_step_id"] == "step-Backlog"
            assert by["P2-02"]["workflow_step_id"] == "step-Done", "resolved ticket must land in Done"
            n = len(calls)
            kb.sync_ticket_cards("ws", "wf", steps, "repo", root)
            assert [c for c in calls[n:] if c[0] != "GET"] == [], "second sync must change nothing"
            # the ticket moves on: the card follows, no duplicate
            f.write_text(f.read_text(encoding="utf-8").replace("ready-for-agent", "claimed"), encoding="utf-8")
            kb.sync_ticket_cards("ws", "wf", steps, "repo", root)
            assert len(store) == 2
            assert by["P2-01"]["workflow_step_id"] == "step-Build (worktree)"


if __name__ == "__main__":
    test_unreachable_raises_friendly_error()
    test_column_for_status()
    test_ticket_cards_parse_files()
    test_card_titles_fit_kandev_limit()
    test_sync_creates_moves_and_is_idempotent()
    print("state:", test_state())
    print("ticket cards:", test_ticket_cards_live())
    test_idempotent()
    print("PASS")
