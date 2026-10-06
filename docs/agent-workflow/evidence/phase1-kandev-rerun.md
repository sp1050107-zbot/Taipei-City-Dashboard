# Phase 1 驗收重跑（Kandev session 實測）

目的：Phase 1 原本是在主對話 session 裡實作與驗收，Kandev 裡沒有任何記錄（8 張 `P1-xx` 任務全是 `CREATED`、0 則訊息）。本次在 Kandev 為每張任務各開一個 Claude session，**唯讀重跑**驗收，讓真實的指令與輸出留在 session 紀錄裡。
結論只引用各 session 這次實際執行的輸出；下表的「與既有文件」欄是各 session 自行比對的結果，其中兩項我已獨立驗證（見 §3）。

## 1. 做法
- 每個 session 由 `session.launch`（`intent: start_created`）啟動在該任務預先建立的 worktree（基準 `develop@cbf9e1f`），agent profile 為 `claude-acp` Default。
- 提示詞分兩段：共同硬性規則＋各任務的驗收條件。共同規則**明確列出要先讀的檔案**（`CLAUDE.md`、`MEMORY.md`、`HANDOFF-phase1.md`、`phase1-issue-log.md`、計畫對應的 Task），所以下面「先讀了文件」是被指示的行為，**不能**當成 session 自發遵守 `CLAUDE.md` 的證據。要觀察「只給一句話時是否自己遵守 `CLAUDE.md`」，用的是另一個任務 `P2-00`（提示詞只有使用者那一句，見另文）。
- 硬性規則：唯讀、不改容器/映像/volume/網路、不 commit/push/merge、不讀 `docker/.env` 與 `mapbox-key.txt`、檢查盡量合併成一次 Bash。
- 每個 Bash 呼叫都經使用者在 Kandev 介面核准；我另外在核准前逐一預審指令全文。

## 2. 結果

| 任務 | session | Bash/工具呼叫 | 結果 | 備註 |
|---|---|---|---|---|
| P1-01 文件三件組 | `7a2d5b32` | 7 | **5/5 PASS** | `check-docs.sh` PASS；CLAUDE.md 25 行；AGENTS.md 9 條規則；MEMORY 連結目標都存在；三檔已在 develop |
| P1-02 程式碼地圖 | `ed1f0c35` | 7 | **4/4 PASS** | 9 份文件共 2329 行；`qdrant.go` 102/130/142 的 `log.Fatalf` 與 `app.go:47` 屬實；HANDOFF 五標頭齊全 |
| P1-03 部署決策 | `b6192846` | 7 | **PASS（有 2 處行號偏差）** | 五標頭、最後一節為 `GSTACK REVIEW REPORT`；12 條 ruling 仍「待使用者確認」，session 未代為確認 |
| P1-04 make-env | `fc6bf98b` | 8 | **4/4 PASS** | `test-make-env.sh` PASS；分支領先 `develop` 2 個 commit（`bdfbe6c`、`df37232`）；`develop` 上不存在 `make-env.sh`＝尚未合併 |
| P1-05 基礎設施 | `70c113f1` | 8 | **8/8 PASS** | 4 容器 running、2 個 PostGIS 可連線、Redis `PONG`、Qdrant 無 key 回 401、`br_dashboard` 存在、`docker/.env` 權限 600 且被忽略、整合 checkout 乾淨 |
| P1-06 初始化 | `2c9d827e` | 12 | **7/7 PASS** | 3 個 init 容器 `exited/0`；dashboard DB 17 表、14 張示範表皆有列數且與證據檔逐字相同（如 `bus_info_tpe=3888`）；manager DB 20 表、`auth_users=1/dashboards=8/components=8/groups=4/roles=3`；`node_modules` 存在；未重跑（以時間戳＋列數旁證） |
| P1-07 起應用 | `7a5139ec` | 8 | **6/6 PASS** | FE 200＋標題；BE 帶斜線 200、不帶 301；代理 200（public 0／taipei 2／metrotaipei 3／personal 0）；`model.onnx` 1,110,007,849 B、`tokenizer.json`、`libonnxruntime.so` 都在；`0.0.0.0:8080` 在 log |
| P1-08 驗收收尾 | `0ca1d669` | 19 | **PASS；管理員登入維持 UNVERIFIED** | 證據檔 §1–§8 與 `qa/` 檔案齊全；FE/BE/DB 數字全部與證據檔一致；在 `$TMPDIR` 重跑瀏覽器探針，三頁 console 錯誤與失敗請求筆數與 §8 相同（`/dashboard` 0、`/mapview` 7、`/admin` 0；GA 請求 2/4/1） |

整體：**8 個任務的可驗證條件全部 PASS，沒有數字漂移或回歸。** 唯一仍是 UNVERIFIED 的是管理員登入（密碼只在 `docker/.env`，防護機制禁止代理讀取，各 session 也依規則沒有嘗試繞過）。

## 3. 這次重跑抓到的文件問題（只列出，尚未修改）

| # | 問題 | 驗證 | 影響的檔案 |
|---|---|---|---|
| R1 | `GET("/", …)` 實際在 `router.go` **第 138–139 行**，不是 137（137 是 `{`）。程式碼引文正確，行號錯。 | 我已獨立驗證（`awk NR` 取行） | `docs/decisions/0001-…:17,53,130`、`phase1-issue-log.md` B8、`.planning/codebase/LEARNINGS-phase1.md:63` |
| R2 | `psql -f` 的 `exec.Command` 實際在 `initial.go` **第 170 行**；引用範圍 `172-178` 只涵蓋 `cmd.Run()` 與錯誤處理，沒包含最關鍵的那一行。 | 我已獨立驗證（`grep -n`） | `docs/decisions/0001-…:55`、`phase1-issue-log.md` B11 |
| R3 | 證據檔 `phase1-verification.md` **完全沒有** Task 2–5（P1-01 到 P1-04）的驗收輸出；`MEMORY.md` 索引寫成「逐項實測輸出」，與事實不符（它只覆蓋 Task 6–9）。 | P1-01、P1-02、P1-04 各自 grep 證據檔 | `MEMORY.md:7`、`evidence/phase1-verification.md` |
| R4 | `HANDOFF-phase1.md:29` 只寫 commit `bdfbe6c`，但 `feature/make-env` 有 2 個 commit（另有修復 `df37232`）。 | P1-04 實測 `log develop..HEAD` | `.planning/HANDOFF-phase1.md` |
| R5 | 證據檔 §6 的 `docker image ls --digests` 區塊漏列 `dashboard-be-dev:latest`（只在正文提到 3.01 GB）。 | P1-08 重跑 | `evidence/phase1-verification.md` §6 |
| R6 | `HANDOFF`／`MEMORY` 沒提到 Kandev 已存在 `feature/p2-00-phase-2-far` 分支與其 commit（Phase 2 準備 session 的產物）。 | P1-08 | `.planning/HANDOFF-phase1.md`、`MEMORY.md` |
| R7 | 計畫 Task 2 Step 3 內嵌的 `AGENTS.md` 模板只有 6 條工作規則，現行檔案是 9 條（歷史快照未同步）。 | P1-01 | `docs/superpowers/plans/…:Task 2` |
| R8 | 證據檔的時間點已過時：容器 uptime 當時 `Up 2 hours`，重跑時 `Up 19–20 hours`；`dashboard-be` 記憶體 2.613 GiB→1.533 GiB。屬取樣時間差，不是錯誤。 | P1-05、P1-07 | `evidence/phase1-verification.md` §6 |

## 4. 環境與規則遵守觀察

- **Kandev agent 的 shell `PATH` 沒有 `docker`**：P1-05、P1-06、P1-07、P1-08 都先吃到 `command not found: docker`，需改用 `~/.docker/bin/docker`（或補 `PATH`）。這點此前未記錄在任何文件（`AGENTS.md`／`MEMORY.md` 都沒有）。
- **「一次 Bash」規則**：P1-01、P1-03 做到；P1-02 用了 3 次（自述是看到初步結果才追查精確行號）；P1-05、P1-06、P1-07 因 `docker` 路徑問題多一次；P1-08 分成兩次（資料庫/容器、瀏覽器探針）。
- **暫存檔位置**：規則要求寫 `$TMPDIR`。P1-07 寫到 `/tmp`（自述「`$TMPDIR` 等效位置」），其實 macOS 的 `$TMPDIR` 是 `/var/folders/…`，這是小偏差；兩者都在 repo 之外，無實際影響。
- **`.serena/` 未追蹤目錄**：P1-01、P1-02、P1-08 都在各自 worktree 的 `git status` 看到它，並如實揭露、沒有刪除或 commit（推測是 Serena MCP 整合在 session 目錄自動建立）。它會污染每個 worktree 的 `git status`，建議之後加進 `.git/info/exclude`。
- 8 個 session 都依指示先讀了專案文件（至少 `HANDOFF-phase1.md`、`phase1-issue-log.md`，多數也讀 `MEMORY.md` 與計畫）才動手，並且都沒有碰 `docker/.env`、`mapbox-key.txt`，沒有 commit/push/merge，沒有改變任何容器；這些屬於「遵守了我給的規則」，不是自發行為。
- 沒有任何 session 自行「確認」尚待使用者決定的項目（12 條 ruling、`feature/make-env` 合併、管理員登入）。

## 5. 仍待處理
- R1 到 R7 的文件修正：等 `P2-00` 的分支處理完再做，因為它也修改了 `phase1-issue-log.md`、決策記錄、`HANDOFF`、`MEMORY.md`、`AGENTS.md`，現在動同一批檔案會造成合併衝突。
- 管理員登入驗證：請使用者自行登入。
- 12 條 ruling、`feature/make-env` 合併核准、git 身分設定：沿用 `phase1-issue-log.md` E 節。
