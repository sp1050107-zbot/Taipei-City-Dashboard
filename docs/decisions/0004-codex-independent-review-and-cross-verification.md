# 0004 Codex 獨立審查與相互驗證

日期：2026-10-08　來源：使用者（大里）指示，Claude Code 與 OpenAI Codex 要「相互驗證協作」，Codex 的價值不可被削弱。
統一規則的**唯一來源**：`/Users/opsai/Documents/sp1050107-zbot/kandev-assistant/docs/plans/2026-09-26-agent-collaboration-evaluation.md`（其中「相互驗證規則」一節補寫中）。本文只引用，不複製內文；該節補完後以它為準，兩者有出入時回報，不自行裁定。

## 取代範圍
取代 `MEMORY.md` 與 `docs/decisions/0001-phase1-deploy-approach.md` 中「本輪不接 Codex」「Codex skipped」的限定。那些限定只在 Phase 1 當時有效；0001 本文不重寫。

## 已決定
1. **Codex＝獨立驗證者**：審 Claude 的計畫、diff 與驗收證據。**只審不修**，不 merge、不 push（唯讀）。
2. **Claude 反向驗證 Codex**：每條審查結論，先查證原始碼或指令輸出再採納；Codex 的報告由 Claude 抽查證據，不照單全收。
3. **Claude 自己的檢查只是前置自檢**：`/code-review`、gstack `/review`、`/cso` 不能取代 Codex 這一關。
4. **`/implement-spec` 內建的 `/code-review` 的處理**：整合分支合併回 `develop` 前，除了 `/code-review` 與決定 0003 的閘門之外，**還必須通過 Codex 獨立審查**。Codex 提出的 CRITICAL／HIGH 未處理，不得放行。
5. **Codex 在 Taipei 的實際用法**（擇一，審查全程唯讀）：
   - gstack `/codex review`（審 diff）或 `/codex consult`（針對特定問題諮詢），在整合 checkout 對整合分支執行；
   - 或在 Kandev 另開一張審查卡，由 Codex 唯讀執行（Kandev 是否已有 Codex 的 agent profile **UNVERIFIED**，開卡前先確認）。
   審查結論寫進該票的 `## Answer` 或 `docs/agent-workflow/evidence/`，並註明 Claude 查證了哪幾條。
6. 這條規則同樣寫在 `AGENTS.md`（Codex 原生讀的是這個檔），`CLAUDE.md` 只放路由表的一列。

## 否決的做法
- 讓 Codex 自己修改、merge 或 push：失去獨立性，也違反規則 3。
- 用 Claude 自己的 `/code-review`、`/review`、`/cso` 取代 Codex：同源偏差，正是要避免的事。
- 在 Taipei 內複製統一規則的全文：兩處內容會漂移，造成互相矛盾的指示。

## 未決定 / UNVERIFIED
- Codex 能否讀到並遵守 `AGENTS.md` 的規則（`phase1-issue-log.md` A5：安裝時有 80 處 `.claude` 路徑未替換）。驗證步驟已列在該檔的「A5 驗證步驟」，**取得大里同意前不啟動 Codex**。
- Kandev 的 Codex agent profile 是否存在、能否設成唯讀。
