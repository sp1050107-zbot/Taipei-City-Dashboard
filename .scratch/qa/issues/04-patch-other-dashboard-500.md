# 04: 改別人的個人儀表板回 500 而不是 403／404

**What to build:** 對不屬於自己的 dashboard 做 PATCH／DELETE，回 403 或 404，不回 500。

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`、`docs/qa/README.md`，以及本票列出的證據。

## Bug

- 發現於：`docs/qa/runs/2026-10-11-3.md`　環境：`develop` @ `92c8057d`，Phase 1 容器
- 嚴重度：S3　所屬層：後端
- 重現步驟：
  1. `qa-editor` 建個人儀表板（POST `/api/v1/dashboard/`）。
  2. `qa-admin` PATCH `/api/v1/dashboard/<index>`。
- 預期：403 或 404（含清楚訊息）。
- 實際：500，`record not found`。
- 證據：`docs/qa/evidence/qa-3/probe-1.out`（「admin2 patch editor dash」列）
- 候選檔案：
  - `Taipei-City-Dashboard-BE/app/controllers/dashboard.go:215` — UpdateDashboard（來源：讀碼）
- 影響範圍（修復完成後填）：endpoint／頁面／測試
- 退回次數：0

## Acceptance criteria

- [ ] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [ ] 修復後該測試通過，既有測試仍全部通過。
- [ ] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [ ] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。
