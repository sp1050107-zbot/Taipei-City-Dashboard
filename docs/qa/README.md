# QA 品質流程（縮小範圍版）

狀態：2026-10-10 起生效。大里在 2026-10-10 選了「Q2：縮小範圍」，取代原本的 `Q 品質迴圈` 設計。
原設計與取捨：`docs/superpowers/specs/2026-10-07-qa-loop-workflow-design.md`（開頭的「範圍調整」一節）。

## 一句話

需要時由擁有者叫一個 session 跑 `/qa-only` 巡檢；每個發現寫成一張 `.scratch/qa/issues/` 的票；修復走既有的 `/implement-spec`；合併前過 `/code-review` 與 Codex；複驗用另一個 session。

## 和原設計的差別

| 原設計（不做） | 縮小版（現在） |
|---|---|
| 第三條 Kandev workflow `Q 品質迴圈`（10 欄） | 不新增 workflow；票的卡片由 `kandev_bootstrap.py` 同步到 `B 客製開發` |
| 欄位移入就自動啟動 agent | **不自動啟動**，每一步都由擁有者叫 session |
| agent 自己建卡、移卡 | agent 只寫票檔；卡片由同步腳本處理（`AGENTS.md`「追蹤與領域文件」） |
| PM agent 自動寫摘要檔 | 擁有者要求時才寫，放 `docs/qa/runs/` |

## 流程

### 1. 巡檢（QA Run）

由擁有者在一個新 session 下令，例如「依 `docs/qa/README.md` 對目前運行中的服務做巡檢，範圍是 …」。

1. **先做就緒探測**：
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/api/v1/dashboard/   # 結尾要有斜線
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/
   ```
   任一不是 200 → 在報告記「環境未就緒」並結束。**這不算 bug，不開票**；重啟服務是擁有者的事（`AGENTS.md` 規則 7）。
2. **只測、只報告，不修**：用 gstack `/qa-only`，不用會改碼的 `/qa`。
3. **範圍**：以擁有者指定的範圍為主。未指定時，可用知識圖找最近改動影響的頁面與 endpoint（見下方「知識圖」），再加少量抽樣。
4. **寫入類測試**：只用含 `qa-<報告編號>` 的可辨識資料，結束前清除；清不掉的要在報告列出。資料初始化不重跑（`AGENTS.md` 規則 9）。
5. **每個發現**：先比對 `.scratch/qa/issues/` 裡還沒 resolved 的票，避免重複；新問題才用 `templates/bug-ticket.md` 開新票。證據（截圖、curl 輸出，**不含祕密**）放 `docs/qa/evidence/<票號>/`。
6. **報告**：用 `templates/qa-run-report.md`，存 `docs/qa/runs/<YYYY-MM-DD>-<n>.md`。
7. **收尾**：commit（文件類，可直接在整合 checkout 的 `develop`），然後同一回合執行 `python3 docs/agent-workflow/kandev_bootstrap.py` 讓看板出現新卡，再用 `python3 docs/agent-workflow/test_kandev_bootstrap.py` 驗證（`AGENTS.md` 的強制規則）。

### 2. 分流與修復

1. 擁有者挑要修的票。小的單票可直接叫一個 session 處理；多張票可用 `/to-tickets` 整理後跑 `/implement-spec`。
2. 修復一律在 worktree，失敗測試先行（`AGENTS.md` 規則 1）。無法用單元測試重現的問題（例如純視覺），在票上寫明改用什麼證據，由複驗時用真實服務確認。
3. 修完把「影響範圍」寫進票（受影響的 endpoint、頁面、測試），可以用知識圖反查。
4. 合併回 `develop` 前：`/code-review` 是前置自檢，**還必須通過 Codex 獨立審查**（`docs/decisions/0004-codex-independent-review-and-cross-verification.md`）。合併由擁有者核准。

### 3. 複驗（Re-verify）

1. **用另一個 session**，不得是修復的那一個。
2. 執行票上的原重現步驟，以及「影響範圍」列出的回歸項目。
3. 通過 → 票改 `Status: resolved` 並寫 `## Answer`（含證據路徑）。
4. 失敗 → 附新證據、`退回次數` 加一，退回修復。**退回次數到 2 次後停手**，在票上寫 `ESCALATED`，交給擁有者決定。
5. 票的狀態一有變動，就跑 `kandev_bootstrap.py` 同步看板。

## 嚴重度

| 級別 | 定義 | 例 |
|---|---|---|
| S1 | 核心功能完全不可用或資料毀損 | 登入失敗、儀表板整頁空白、後端啟動崩潰 |
| S2 | 主要功能錯誤但有繞路 | 單一圖表資料錯誤、管理後台某操作失敗 |
| S3 | 次要功能或邊界情況錯誤 | 篩選條件在特定組合失效 |
| S4 | 外觀、文字、非功能性問題 | 錯字、對齊 |

S1 與跨前後端的問題，修之前先用 gstack `/plan-eng-review` 做決策，記錄放 `docs/decisions/`。

## 知識圖（提示，不是結論）

圖在 `.ua/knowledge-graph.json`（本機產物，不入版控）。查詢工具在 `~/Understand-Anything` fork：

```bash
node ~/Understand-Anything/scripts/graph-query.mjs ~/Taipei-City-Dashboard chain "<症狀，例如 endpoint 或頁面>"
node ~/Understand-Anything/scripts/graph-query.mjs ~/Taipei-City-Dashboard impact <檔案路徑>... [--depth N]
```

`.vue` 檔的資訊有限，資料工程沒有資料流；候選檔案要標明「來源：圖」或「來源：讀碼」，並一定要讀碼確認。圖過期時（`.ua/meta.json` 的 commit 與 `develop` 不一致），在票或報告註明，由擁有者執行 `/understand` 與 `augment-gin-vue.mjs` 更新。

## 保護規則

- 祕密：`mapbox-key.txt`、`docker/.env` 不讀、不印、不 commit；每次 commit 前用完整字串比對 staged diff（只比對，不印出）。
- 不 push，除非擁有者明確指示。
- 同一時間只跑一個巡檢 session（服務與資料庫是共用的單一環境）。
- 環境未就緒不算 bug。
- 修復者不驗自己的修復；Codex 只審不修。
