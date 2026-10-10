# 03: ai-summary/trigger 未掛管理者驗證，匿名可觸發 DAG

**What to build:** 只有系統管理者能 POST `/component/ai-summary/trigger`；匿名回 403。

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`、`docs/qa/README.md`，以及本票列出的證據。

## Bug

- 發現於：`docs/qa/runs/2026-10-11-3.md`　環境：`develop` @ `92c8057d`，Phase 1 容器
- 嚴重度：S2　所屬層：後端；本票只依讀碼，未實際執行（執行會觸發 Airflow DAG，屬有副作用）
- 重現步驟：
  1. 讀 `router.go` 的 `configureComponentRoutes`：`IsSysAdm()` 在 `componentRoutes.Use(...)` 之後才生效，而 `/ai-summary/trigger` 在它之前註冊。
  2. 驗證時（需擁有者同意觸發 DAG）：不帶 token POST `/api/v1/component/ai-summary/trigger`，body `{"index":"qa-3","type":"chart"}`。
- 預期：403。
- 實際：依讀碼推論會進到 handler 並呼叫 Airflow（**未實測**）。
- 證據：無（未執行）。
- 候選檔案：
  - `Taipei-City-Dashboard-BE/app/routes/router.go:114` — 路由註冊順序（來源：讀碼）
  - `Taipei-City-Dashboard-BE/app/controllers/componentAISummary.go:86` — handler（來源：讀碼）
- 影響範圍（修復完成後填）：endpoint／頁面／測試
- 退回次數：0

## Acceptance criteria

- [ ] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [ ] 修復後該測試通過，既有測試仍全部通過。
- [ ] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [ ] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。
