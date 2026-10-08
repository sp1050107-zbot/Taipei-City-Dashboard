# A5 驗證證據：Codex 能讀到並遵守 Taipei 的 AGENTS.md 規則嗎？

日期：2026-10-08　執行：Claude Code（依大里指示，步驟見 `../phase1-issue-log.md` 的「G. A5 驗證步驟」）
結論：**對 `AGENTS.md` 規則無影響 ✅**；`CLAUDE.md` 對 Codex **不可見**，已證實 `docs/decisions/0004` 第 6 點的前提。

## 環境（指令輸出，非記憶）
- `codex-cli 0.155.1`；`codex exec --help` 的 `-s, --sandbox` 可選值：`read-only`、`workspace-write`、`danger-full-access`。
- **`~/.codex/config.toml` 的預設 `sandbox_mode = "danger-full-access"`、`approval_policy = "never"`**。所以 Codex 預設不是唯讀，**每次呼叫都必須明確帶 `-s read-only`**，不能靠預設。
- Codex 的啟動橫幅確認 `sandbox: read-only`、`workdir: /Users/opsai/Taipei-City-Dashboard`、model `gpt-5.6-luna`。

## 步驟 1：盤點 80 處 `.claude`（不啟動 Codex）
`grep -rIl '\.claude' ~/.codex` 的命中檔都屬於以下三類，**沒有一個在 `AGENTS.md` 的載入路徑上**（`~/.codex/AGENTS.md` 為 0 行）：
- (a) `~/.codex/agents/gsd-*.md|.toml`：gsd 的 agent 定義內文引用 `.claude` 路徑；
- (b) `~/.codex/plugins/cache/...`：superpowers、gstack-workflows、code-review 外掛的內文與資產；
- (c) `~/.codex/archived_sessions/*.jsonl`、`.codex-global-state.json`：舊 session 紀錄與狀態。
註：grep 總命中 10070 次（含 session 紀錄），與安裝器警告的「80 處」不是同一個量；本驗證只回答「是否影響 AGENTS.md 規則」，沒有逐一核對那 80 處。

## 步驟 3：正向探針（`codex exec -s read-only --ephemeral -C ~/Taipei-City-Dashboard`，提示詞不提 AGENTS.md 檔名）
| 題目 | Codex 回答（摘錄） | 預期 | 結果 |
|---|---|---|---|
| 誰可以跑 docker compose | 只有整合 checkout（`~/Taipei-City-Dashboard/docker`）——AGENTS.md | 規則 7 | ✅ |
| 可以 git push 嗎 | 不可以，除非使用者明確指示——AGENTS.md | 規則 3 | ✅ |
| ADR 放哪 | `docs/decisions/`，不建立 `docs/adr/`——AGENTS.md | 追蹤與領域文件 | ✅ |
| 合併回 develop 前還需要什麼 | `/code-review` 與驗證，並經 Codex 獨立審查通過——AGENTS.md | 規則 1 與 0004 | ✅ |

Codex 自己列出載入的專案指示檔：只有 `AGENTS.md`。

## 步驟 4：負向探針（只寫在 `CLAUDE.md` 的內容）
- 「角色路由表的『獨立驗證』指定誰」→ **「上下文中沒有」**。證明 Codex 看不到 `CLAUDE.md`（該列只在 `CLAUDE.md` 第 11 行）。
- 「Kandev 欄位順序」→ Codex 答「Backlog → Build (worktree) → Verify → Done」，來源標 `AGENTS.md`。這是從 `AGENTS.md` 的票狀態對應規則（ready-for-agent→Backlog、claimed→Build、→Verify、→Done）拼出的子集，**缺少 `CLAUDE.md` 才有的完整七欄（含 Decide、Context、Merge-ready）**。這同樣顯示 `CLAUDE.md` 的內容 Codex 讀不到，且它有可能把部分資訊拼成看似完整的答案。

## 步驟 5：判讀與副作用檢查
- 四題全答對，且沒有任何工具呼叫（log 中 `git push` 字樣只出現在題目與答案文字）。
- 執行前後：`git status --porcelain` 無差異、`HEAD` 未變 → 沒有寫檔、commit、merge 或 push。

## 後續與限制
1. **規則一律寫進 `AGENTS.md`**；`CLAUDE.md` 只放給 Claude 的補充。Codex 若需要 `CLAUDE.md` 獨有的資訊（如 Kandev 完整欄位），要在審查任務簡報中明列或改寫進 `AGENTS.md`。
2. **唯讀必須每次明確指定**：`codex exec -s read-only`（預設是 `danger-full-access`）。gstack `/codex`：讀原始碼確認（2026-10-08，未實跑）`~/.claude/skills/gstack/bin/gstack-codex-probe` 由 `_gstack_codex_sandbox_mode` 統一設定 `sandbox_mode="read-only"`，只有使用者匯出 `GSTACK_CODEX_NO_SANDBOX=1` 才給完整權限；目前環境與 `~/.zshrc` 都沒有設這個變數。**不要設定它。**
3. 本次只驗證「讀得到並遵守規則」；**Codex 實際審 diff 的品質、Kandev 的 Codex agent profile 能否設成唯讀仍是 UNVERIFIED**（見 `0004`）。
4. 單次、單模型（`gpt-5.6-luna`）的結果，不代表所有設定檔 profile 的行為。
