# 05: 登入 email 格式錯誤時，回應的 error 是空物件 {}

**What to build:** email 格式錯誤時回可讀的錯誤字串。

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`、`docs/qa/README.md`，以及本票列出的證據。

## Bug

- 發現於：`docs/qa/runs/2026-10-11-3.md`　環境：`develop` @ `92c8057d`，Phase 1 容器
- 嚴重度：S4　所屬層：後端
- 重現步驟：
  1. POST `/api/v1/auth/login`，Basic 認證帳號用 `notanemail`。
- 預期：`{"error":"invalid email format ..."}`。
- 實際：`{"error":{}}`（把 error 物件直接放進 gin.H，序列化後為空）。
- 證據：`docs/qa/evidence/qa-3/probe-1.out`（「login bad email fmt」列）
- 候選檔案：
  - `Taipei-City-Dashboard-BE/app/controllers/auth.go:43` — `fmt.Errorf(...)` 直接放進 gin.H（來源：讀碼）
- 影響範圍（修復完成後填）：endpoint／頁面／測試
- 退回次數：0

## Acceptance criteria

- [ ] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [ ] 修復後該測試通過，既有測試仍全部通過。
- [ ] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [ ] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。
