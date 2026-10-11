# 01: 任何登入者可讀寫刪他人的地圖視角（viewpoint）

**What to build:** 只有本人（或系統管理者）能讀、建、刪自己的 viewpoint；他人請求回 403。

**Blocked by:** None (can start immediately)

**Status:** resolved

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
- 證據：`docs/qa/evidence/qa-3/probe-2-output.txt`（「editor READ／CREATE／DELETE admin vp」三列）、`probe-2.py`
- 候選檔案：
  - `Taipei-City-Dashboard-BE/app/controllers/viewPoints.go:16,42,61` — 三個 handler 未比對 `:id` 與登入者（來源：讀碼，未逐行確認）
  - `Taipei-City-Dashboard-BE/app/routes/router.go` — `/user/:id/viewpoint` 只掛 IsLoggedIn（來源：讀碼）
- 影響範圍：endpoint `GET`／`POST /api/v1/user/:id/viewpoint`、`DELETE /api/v1/user/:id/viewpoint/:viewpointid`（非本人一律 403；刪除 0 筆由 200 改 404）；頁面：地圖頁的視角清單（`Taipei-City-Dashboard-FE/src/store/mapStore.js`，只用自己的 `user_id`，不受影響）；測試：`app/middleware/common_test.go`、`app/routes/router_test.go`、`app/models/viewPoints_test.go`、`app/controllers/viewPoints_test.go`
- 退回次數：0

## Acceptance criteria

- [x] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [x] 修復後該測試通過，既有測試仍全部通過。
- [x] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [x] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。

## Answer

已修正並併入 `develop`：`917e92a2`（分支 `feature/qa-01-03-authz` @ `46b3d0aa`，未 push）。作者是 Taipei｜主線，驗收是 Taipei｜QA。

- 修法：新增 `middleware.IsSelf("id")`，`/user/:id/viewpoint` 三條路由都掛 `IsLoggedIn` + `IsSelf`；`models.DeleteViewPoint` 刪除 0 筆時回 `gorm.ErrRecordNotFound`，controller 回 404。
- **與本票「What to build」不同**：本票寫「只有本人（或系統管理者）」，實作是管理者也只能動自己的（沒有管理者例外）。依據是 Codex 審查的修法方向「預設只限本人，管理者也一樣；管理者若需要管理他人的 viewpoint，另開明確的管理路由」（`docs/agent-workflow/evidence/codex/2026-10-11-qa-01-03-review.md`）。前端沒有管理者代管 viewpoint 的功能。
- 本票原本寫的「回應帶出 admin email」不成立（程式沒有 `Preload`，證據截斷），QA 已更正。
- 測試：先 RED 後 GREEN，後端全套 `go test -vet=off ./...` 全部 ok。
- 複驗：Taipei｜QA 報告 `docs/qa/runs/2026-10-11-5.md`（離線層 PASS）、`2026-10-11-6.md`（對 8089 上修正分支的後端，PASS；QA 分支 `356e1db3`）。
- 審查：Codex 唯讀 GATE: PASS（併入前）。`/code-review` 是**併入後才補跑**的，所以對應的驗收條件保持未勾選。補跑結果：Standards 沒有違反書面規範；Spec 沒有實作錯誤。
- 後續（不阻擋，未修）：
  - 路由測試只測了本人的 GET，本人的 POST／DELETE 沒走路由測試。
  - 測試輔助函式命名與 `t.Run` 沒照 `.planning/codebase/TESTING.md`。
  - 路由測試沒有經過 `configure*Routes` 與限流器（Codex P2）。
- 8088 的原生後端已在併入後重啟，修正已生效。
