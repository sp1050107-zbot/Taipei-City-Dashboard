@AGENTS.md

# Claude 專用補充

## 角色路由（缺什麼就找哪一層）
| 我缺的是… | 用 | 例 |
|---|---|---|
| 決策（該不該做、範圍、架構取捨） | gstack | `/office-hours` `/plan-eng-review` |
| 背景（專案現況、程式碼地圖、跨 session 交接） | GSD | `gsd-map-codebase` `gsd-resume-work` |
| 執行（TDD、worktree、驗證） | superpowers | `test-driven-development` `verification-before-completion` |
| 獨立驗證（審計畫／diff／驗收證據） | Codex（唯讀） | `/codex review` `/codex consult`，見 `docs/decisions/0004-codex-independent-review-and-cross-verification.md` |

## Kandev
- 網址 `http://127.0.0.1:38429`，workspace `taipei-city-dashboard`，兩條 workflow：`A 部署與研究`、`B 客製開發`。
- 一個 task = 一個 session；欄位順序 Backlog → Decide → Context → Build → Verify → Merge-ready → Done。
- task 前綴與既有 workspace 同為 `KAN`（Kandev 自動指派），請用標題前綴 `P1-xx` 辨識本專案的 task。
- 重建/補種：`python3 docs/agent-workflow/kandev_bootstrap.py`（冪等）。它也會把 `.scratch/*/issues/` 的每張票同步成一張卡；**票一有變動就要跑**（Kandev 是擁有者回查進度用，強制，見 AGENTS.md）。

## Context 快滿時
1. 執行 `gsd-pause-work` 寫交接。
2. 更新 `MEMORY.md`（只加一行索引，細節放獨立檔）。
3. 新 session 用 `gsd-resume-work` 接續。

## 知識圖（Understand-Anything）
- 圖在 `.ua/knowledge-graph.json`（本機產物，已 gitignore、不入版控）；`/understand` 建圖、`/understand-dashboard` 看圖。
- 每次 `/understand` 之後要補後端路由與前端 import：`node ~/Understand-Anything/scripts/augment-gin-vue.mjs ~/Taipei-City-Dashboard`（可重跑）。
- 圖看「誰呼叫誰、改動影響哪裡」；`.planning/codebase/` 看「為什麼、有什麼風險」。

## 常用檢查
- 文件三件組：`bash docs/agent-workflow/check-docs.sh`
- Kandev 狀態：`python3 docs/agent-workflow/test_kandev_bootstrap.py`

## Agent skills

### Issue tracker

Tickets and specs are local markdown under `.scratch/`; each ticket has one Kandev card that only points to its file. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five roles, recorded as `Status:` text in each ticket file (no GitHub labels). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the repo root, decisions (what other templates call ADRs) in `docs/decisions/`. See `docs/agents/domain.md`.

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. Route only to skills in the session's available-skills list; answer directly for quick questions or small scoped edits.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
