# 02: 新增 contributor 第一次必回 500（序號未同步）

**What to build:** 管理者新增 contributor 第一次就成功；其他以示範資料帶入固定 id 的表（issues、components）不會在之後撞主鍵。

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`、`docs/qa/README.md`，以及本票列出的證據。

## Bug

- 發現於：`docs/qa/runs/2026-10-11-3.md`　環境：`develop` @ `92c8057d`，Phase 1 容器
- 嚴重度：S2　所屬層：後端；疑似根因在示範資料而非 Go 程式碼
- 重現步驟：
  1. 全新初始化後，用 `qa-admin` 登入。
  2. POST `/api/v1/contributor/`，body `{"user_id":"qa-3","user_name":"qa-3","link":"http://x.example","image":"a.png"}`。
  3. 重複送出直到成功，之後刪掉建出的資料。
- 預期：第一次即 200。
- 實際：500，`duplicate key value violates unique constraint "contributors_pkey"`；第 2 次才成功（id 3）。重現兩次（`probe-1.out`、`probe-2.out`）。
- 同類風險（唯讀查證，`select max(id)` 對照序號）：issues max=4 序號從 1 起（再建 3 筆後撞 id 4）；components max=218、序號未用過（建到 id 60 會撞）。dashboards、groups 沒問題（示範檔有 setval）。
- 證據：`docs/qa/evidence/qa-3/probe-1.out`、`probe-2.out`
- 候選檔案：
  - `db-sample-data/dashboardmanager-demo.sql:142,151` — 只對 dashboards、groups 做 setval（來源：讀碼）
  - `Taipei-City-Dashboard-BE/app/models/contributor.go` — 資料表定義（來源：讀碼）
- 影響範圍（修復完成後填）：endpoint／頁面／測試
- 退回次數：0

## Acceptance criteria

- [ ] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [ ] 修復後該測試通過，既有測試仍全部通過。
- [ ] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [ ] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。
