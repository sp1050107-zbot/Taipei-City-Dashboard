# NN: <一句話標題，連同票號不超過 60 字元的看板標題會自動截短>

**What to build:** <修好之後，使用者會看到什麼正確的行為>

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Read first (nothing else is assumed):** `AGENTS.md`、`docs/qa/README.md`，以及本票列出的證據。

## Bug

- 發現於：`docs/qa/runs/<YYYY-MM-DD>-<n>.md`（或「手動」）　環境：`develop` @ `<short sha>`，Phase 1 容器或 Phase 2 原生
- 嚴重度：S? 　所屬層：前端／後端／資料工程　備註：<例：疑似與 qa-NN 重複>
- 重現步驟：
  1. …
  2. …
- 預期：…
- 實際：…
- 證據：`docs/qa/evidence/qa-NN/…`（不得含祕密）
- 候選檔案：
  - `<path>` — <為何相關>（來源：圖／讀碼）
- 影響範圍（修復完成後填）：endpoint／頁面／測試
- 退回次數：0

## Acceptance criteria

- [ ] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [ ] 修復後該測試通過，既有測試仍全部通過。
- [ ] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [ ] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。
