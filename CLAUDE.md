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
- task 前綴與既有 workspace 同為 `KAN`（Kandev 自動指派），請用標題前綴 `P1-xx` 辨識本專案的 task。
- 重建/補種：`python3 docs/agent-workflow/kandev_bootstrap.py`（冪等）。

## Context 快滿時
1. 執行 `gsd-pause-work` 寫交接。
2. 更新 `MEMORY.md`（只加一行索引，細節放獨立檔）。
3. 新 session 用 `gsd-resume-work` 接續。

## 知識圖（Understand-Anything）
- 圖在 `.ua/knowledge-graph.json`；`/understand` 建圖、`/understand-dashboard` 看圖。
- 每次 `/understand` 之後要補後端路由與前端 import：`node ~/Understand-Anything/scripts/augment-gin-vue.mjs ~/Taipei-City-Dashboard`（可重跑）。
- 圖看「誰呼叫誰、改動影響哪裡」；`.planning/codebase/` 看「為什麼、有什麼風險」。

## 常用檢查
- 文件三件組：`bash docs/agent-workflow/check-docs.sh`
- Kandev 狀態：`python3 docs/agent-workflow/test_kandev_bootstrap.py`
