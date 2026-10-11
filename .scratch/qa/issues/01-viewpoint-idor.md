# 01: 任何登入者可讀寫刪他人的地圖視角（viewpoint）

**What to build:** 只有本人（或系統管理者）能讀、建、刪自己的 viewpoint；他人請求回 403。

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`、`docs/qa/README.md`，以及本票列出的證據。

## Bug

- 發現於：`docs/qa/runs/2026-10-11-3.md`　環境：`develop` @ `92c8057d`，Phase 1 容器
- 嚴重度：S2　所屬層：後端；備註：資安類，建議修前先過 `/plan-eng-review`
- 重現步驟：
  1. 用 `qa-admin` 登入，POST `/api/v1/user/2/viewpoint` 建一筆。
  2. 用 `qa-editor`（非管理者，user_id 3）登入，GET `/api/v1/user/2/viewpoint`。
  3. 同一帳號 POST `/api/v1/user/2/viewpoint`，再 DELETE `/api/v1/user/2/viewpoint/<id>`。
- 預期：2、3 皆 403（路徑 `:id` 不是自己）。
- 實際：皆成功（200／201）。**更正（2026-10-11，經 QA 重測）**：先前寫「回應帶出 admin 的 email 與 is_admin」不成立，那是我從被截斷的輸出推論的；重測時 `AuthUser.account`、`is_admin` 皆為空（零值），沒有洩漏他人 email。越權讀、建、刪三項本身仍成立，S2 不變。
- 證據：`docs/qa/evidence/qa-3/probe-2.out`（「editor READ／CREATE／DELETE admin vp」三列）、`probe-2.py`
- 候選檔案：
  - `Taipei-City-Dashboard-BE/app/controllers/viewPoints.go:16,42,61` — 三個 handler 未比對 `:id` 與登入者（來源：讀碼，未逐行確認）
  - `Taipei-City-Dashboard-BE/app/routes/router.go` — `/user/:id/viewpoint` 只掛 IsLoggedIn（來源：讀碼）
- 影響範圍（修復完成後填）：endpoint／頁面／測試
- 退回次數：0

## Acceptance criteria

- [ ] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [ ] 修復後該測試通過，既有測試仍全部通過。
- [ ] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [ ] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。
