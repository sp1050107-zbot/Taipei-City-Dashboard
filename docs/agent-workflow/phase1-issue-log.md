# Phase 1 問題與處理總表

日期：2026-10-06　範圍：從檢查三個學習專案的安裝，到 Phase 1 驗收與最終審查。
這份是**完整對照表**：每一列＝一個遇到的狀況、原因/證據、怎麼處理、現況。細節與證據見各連結檔。
補充說明：執行期的暫存 ledger（`.superpowers/`）依規定在結案時刪除，這裡把它的內容（rulings、deferred minors、最終審查結果）保存下來。

狀態圖例：✅ 已解決　🟡 已緩解/已記錄，仍有後續　⏳ 等使用者　❓ 未驗證

## A. 環境前置（Phase 1 之前；發生在 `~/gstack`、`~/gsd-core`、`~/superpowers` 與本機工具）

| # | 狀況 | 原因/證據 | 處理 | 狀態 |
|---|---|---|---|---|
| A1 | `~/gstack` 的 `origin` 指向原作者 `garrytan/gstack`，不是你的 fork；落後 26 個 commit | `git remote -v`；`gh api repos/sp1050107-zbot/gstack` 確認 fork 存在 | `origin` 改名 `upstream`，新增 `origin`＝你的 fork，fast-forward 到 v1.91.25.0 | ✅ |
| A2 | `~/gsd-core` 的安裝器無法執行：`Cannot find module '../gsd-core/bin/lib/shell-command-projection.cjs'` | 倉庫沒有 build 產物 | `npm ci` → `npm run build:lib` | ✅ |
| A3 | gsd 安裝後 hooks 被略過：`gsd-secret-read-guard.js`、`gsd-graphify-update.sh`、`gsd-config-reload.js` 等 "not found at target" | 缺 `hooks/dist` | `npm run build:hooks` 後重裝（Claude 與 Codex 各一次）；`~/.claude/hooks` 確認出現三個 hook | ✅ |
| A4 | Claude Code 裝的是 `get-shit-done` 1.42.3（67 個技能），**不是**你 fork 的 `@opengsd/gsd-core` 1.16.0；Codex 完全沒裝 gsd | `~/.claude/get-shit-done/VERSION`；`~/.codex` 無 gsd | 先備份到 `~/.gstack-dev/backups/gsd-20261006-005627`（約 4.3 MB），再 `node bin/install.js --claude --global`（72 技能、35 agents）與 `--codex --global`（72 技能、99 個 agent toml） | ✅（備份可還原） |
| A5 | Codex 安裝器警告：80 處 `.claude` 路徑未替換 | 安裝輸出 | **未驗證**是否影響 Codex 實際使用 | ❓ |
| A6 | Claude 端 statusline 因「已設定」未被覆蓋 | 安裝輸出 `Skipping statusline` | 保留你原本的設定 | ✅ |
| A7 | gstack `./setup` 需要 `bun`，機器沒有 | `bun: command not found` | 經你同意 `brew install oven-sh/bun/bun`（1.4.2） | ✅ |
| A8 | `./setup --host claude` 回 `skipped … links to ~/.agents/skills/gstack` | 舊安裝是連結到 `~/.agents/skills/gstack`（v1.91.1.0） | 加 `--global` 才取代；現在 `claude`/`codex` 皆為 `~/gstack` 來源、v1.91.25.0，`/qa`、`/ship`、`/review` 等 5 個獨立技能出現 | ✅ |
| A9 | superpowers plugin 是 6.4.1，你的 fork 是 6.4.2 | `installed_plugins.json` | 沒動（走 plugin 市集更新） | 🟡 |
| A10 | 一個 `gh repo clone`（約 1.1 GB）還在跑時 repo 看起來是空的（`HEAD` 無效） | 行程仍在、`.git` 337 MB 持續增長 | 等它結束再操作；`mapbox-key.txt` 加進 `.git/info/exclude`（不改被追蹤檔） | ✅ |
| A11 | gstack 啟動提示：有新版 1.91.27；要不要把 skill routing 寫進專案 `CLAUDE.md` | skill preamble 的一次性指示 | **刻意沒處理**（會改你的安裝/專案檔） | ⏳ |

## B. Phase 1 各 Task

| # | Task | 狀況 | 原因/證據 | 處理 | 狀態 |
|---|---|---|---|---|---|
| B1 | 1 | Kandev 新 workflow 的 steps 回 `null`，`TypeError: 'NoneType' object is not iterable` | 實機回應 | `kandev_bootstrap.py` 用 `or []`；冪等重跑 | ✅ |
| B2 | 1 | 新 workspace 的 task 前綴是 `KAN`（與既有相同），無法在建立時指定 | `GET /workspaces` | 標題用 `P1-xx` 辨識 | 🟡 |
| B3 | 1 | 防洩漏檢查用正則 `pk\.[A-Za-z0-9._-]{20,}`，誤判計畫裡的測試假 token | `git diff --cached` 命中 `pk.TESTSENTINEL…` | 改成用真實 token 做**精確字串比對**（不印出）；計畫 4 處同步 | ✅ |
| B4 | 2 | 上游 `.gitignore:29` 有 `*.sh`，`check-docs.sh` 沒被 commit | `git add` 提示 ignored；`git ls-files` 少一個 | 只對指定腳本 `git add -f`（commit `c0f4ef1`），不改上游 `.gitignore` | ✅（日後 `git add -A` 會漏 `.sh`，我們一律指名加入） |
| B5 | 3 | `task-done` 用 `bash -c '…'` 時沒寫入 ledger | ledger 缺行 | 改用獨立檢查腳本 | ✅ |
| B6 | 3 | mapper（haiku）在 `CONCERNS.md:24` 寫成「把 `log.Fatalf()` 改成 `log.Fatalf()`」 | 閱讀產出 | 內容其餘與我獨立讀碼的結論一致（`qdrant.go:102,130,142`）；**未修**，只記錄 | 🟡 |
| B7 | 4 | `/plan-eng-review` 預設每個決策都要停下來問你 | 規範全文 | 非互動執行、全採建議選項、記為 12 條 ruling；外部審查（Codex）依你指示略過，原生備援因 `TaskOutput` 工具不可用而不可用 | ⏳ 待你確認 |
| B8 | 4 | 就緒探測 `/api/v1/dashboard` 會得到 301 | 讀 `router.go:137` + 實測 301/200 | 探測改帶斜線 | ✅ |
| B9 | 4 | spec/計畫的「BE 失敗就退回純 golang image」行不通 | `app/app.go:47` 無條件載入模型，`qdrant.go` 失敗即 `log.Fatalf` | 移除備案，改成重試/HF token 策略 | ✅ |
| B10 | 4 | nginx、pgAdmin、`vector-db-upgrade` 本機不需要；Docker 只配 8.3 GB | `default.conf`、`docker info` | Phase 1 不啟動（ruling 3–5） | ✅ |
| B11 | 4 | init 容器吞錯、重跑不等價 | `initial.go:136-137,172-178`：`psql -f` 無 `ON_ERROR_STOP`，輸出被丟棄 | 以資料列數驗收；不重跑；重置＝刪兩個 volume | ✅ |
| B12 | 4 | init 在綁定掛載用 Alpine 跑 `npm ci`，`node_modules` 是 musl 版 | `docker-compose-init.yaml` | 記入 Phase 2 注意事項（主機直接 `npm run dev` 前須刪除重裝） | 🟡 |
| B13 | 5 | 第一版測試在 `make-env.sh` 不存在時**靜默退出**，無法證明紅燈原因 | `set -e` 吞掉指令替換失敗 | 呼叫加 `|| fail "…$OUT"` | ✅ |
| B14 | 5 | 沒跑完整 `/review`（Review Army/QA/對抗式），改做手動核心審查 | diff 僅 2 檔；`*.sh` 被忽略導致 logger 看不到候選 | 以實測探針代替（無秘密外洩、權限 600、拒絕覆寫、可被 `source`）；**未寫 `gstack-review-log`** | 🟡 |
| B15 | 5 | 懸空 symlink 作為輸出目標時噴 Python traceback | 實測 | 測試 9 RED→GREEN；`stat` 改 `-c` 優先（Linux 可攜） | ✅ |
| B16 | 5 | 在 worktree 內執行 `task-done` 會把 ledger 寫到 worktree 自己的目錄 | 主 ledger 缺行 | 手動合併一行；之後一律在整合 checkout 執行 | ✅ |
| B17 | 5 | `make-env.sh` 還沒合併進 `develop` | 合併屬需你核准的共享分支動作 | 分支 `feature/make-env`（`bdfbe6c`、`df37232`）保留；Task 6 直接用 worktree 路徑呼叫 | ⏳ |
| B18 | 6 | 兩個 PostGIS 容器是 amd64 映像在 arm64 上模擬運行 | `docker compose` 警告；`docker image inspect` → `amd64/linux` | 沒動（上游 tag 無 arm64 版） | 🟡 |
| B19 | 6/7/9 | 防護 hook 擋下含 `.env` 的指令（連暫存檔名也算） | `Secret read guard: Bash would read …` | 探針輸出檔改名；DB 連線改用容器內 `psql -U postgres`；**不繞過** | ✅ |
| B20 | 7 | 三個 init 容器全 `Exited (0)`，但 dashboard init 沒有成功訊息 | 日誌 | 以資料列數驗收：dashboard DB 14 張示範表皆有資料；manager DB 20 張表、`auth_users=1`、`dashboards=8` | ✅ |
| B21 | 8 | `pip` 在 arm64 解析到 **CUDA 版 PyTorch**（數 GB），pip 層約 49 分鐘（~1.1–1.4 MB/s） | build 日誌 | 不改 Dockerfile（只是建置期一次性成本，且會偏離上游） | 🟡 |
| B22 | 8 | **我的錯**：背景指令上限設 3600000 ms，首次 build 在第 3600 秒被終止（最大值是 7200000） | task 通知 `killed` | 以 7200000 重跑；pip 層 `CACHED`，第二次 559 秒完成；教訓寫入 MEMORY | ✅ |
| B23 | 8 | 計畫的 log 標記 `Listening and serving HTTP` 在此 Gin 版本不存在 | `docker logs` | 改以 HTTP 200 與 `0.0.0.0:8080` 行判斷；約 120 秒才就緒 | ✅ |
| B24 | 8 | 我誤判「dashboards: 0」 | 解析方式錯 | API 依群組回傳：public 0、taipei 2、metrotaipei 3、personal 0（未登入） | ✅ |
| B25 | 9 | 沒用 Aside／`/qa-only` 完整流程，改用 Playwright（gstack 的 `node_modules`、快取的 headless Chromium） | 首次 `Cannot find module 'playwright'` → 設 `NODE_PATH=~/gstack/node_modules` | 三頁取證與截圖；只測「載入/渲染/無 console 錯誤/無 4xx」，**沒測互動、行動版、登入後頁面** | 🟡 |
| B26 | 9 | 管理員登入沒驗證 | 密碼只在 `docker/.env`，hook 禁止代理讀取 | 標為「未驗證」；只驗證路由存活（錯誤帳密回 401）與管理員存在（`auth_users=1`）；請你自己登入 | ❓⏳ |
| B27 | 9 | 前端會把瀏覽資料送到上游 GA | `index.html:31,39` 的 `G-0KD9XLZ7W3` | 只記錄，列為 B 階段第一批客製候選 | 🟡 |
| B28 | 10 | `gsd-extract-learnings`、`gsd-pause-work` 依賴 GSD 階段目錄與 `STATE.md`，本專案沒有 | 工作流程規格 | 以相同格式手寫 `LEARNINGS-phase1.md`、`HANDOFF-phase1.md`；略過 STATE 更新與估時校準 | 🟡 |

## C. 最終全分支審查（全新 context、最強模型）與修正

結果：**0 Critical、8 Important、13 Minor**。Important 已在同一輪全數修正（commit `1973ce0` 與 `df37232`）。

| # | Important | 處理 |
|---|---|---|
| C1 | `MEMORY.md`／`HANDOFF` 寫「Phase 1 已完成並驗收」，但 spec 成功標準含「管理員可登入」未驗證 | 改為「已部署，驗收 3/4 項；管理員登入待驗證」 |
| C2 | Kandev 種子任務標題/描述與 ruling 脫節（還叫人啟動 nginx） | 測試改為逐一比對標題與描述（RED：P1-04 舊標題）→ bootstrap 改成依 `P1-xx` upsert（GREEN）；實機 8 張卡已更新、無重複 |
| C3 | `MEMORY.md` 把防護 hook 的範圍寫反 | 改為「禁止讀 `docker/.env`；`mapbox-key.txt` 可比對但永不印出」 |
| C4 | 計畫要求 `source docker/.env` | 改用容器內 `psql -U postgres`，不載入祕密 |
| C5 | 證據 §3 把 PostGIS tiger 擴充表算成示範資料（「22 張」） | 重列：14 張示範表＋3 個 PostGIS 物件；其餘約 36 張為擴充 |
| C6 | `LEARNINGS` 宣稱證據由腳本產生 | 更正：輸出來自一次執行的 shell 區塊，該區塊未 commit |
| C7 | 計畫仍含不存在的 log 標記與過時的 build 時間估計 | 已更新；計畫內嵌的 bootstrap 程式碼同步為現行檔 |
| C8 | `make-env.sh` 寫入失敗會留下殘檔，之後每次都「拒絕覆寫」 | 測試 10 RED（`ulimit -f` 直接套 shell 無效，因為 here-doc 先失敗，改用只對 python 生效的 PATH shim）→ GREEN：暫存檔＋`os.link` 無覆寫連結，失敗即清除 |

審查者另外指出、我**刻意不修**（規則：Minor 不進修復輪）的 13 項，交由你決定。Phase 2 啟動時順手清掉其中風險低、範圍小的幾項（狀態見各列）：

1. `make-env.sh` 在 git 倉庫外執行會印 git fatal 雜訊，且無覆寫參數時默默寫到 `./docker/.env` — 🟡 未修（腳本在未合併的 `feature/make-env` worktree，待 B17 核准合併後再處理）
2. `ENV_OUT` 不含目錄成分時 `makedirs('')` 噴 traceback — 🟡 未修（同上，同一支腳本）
3. token 檔有兩行時會被串接成一個字串 — 🟡 未修（同上）
4. `test-make-env.sh` 編號為 7、9、8；也沒斷言「未動到的模板行原樣保留」 — 🟡 未修（同上）
5. `AGENTS.md` 的埠表仍列 nginx 80/443、pgAdmin 8889，與同檔規則 8 矛盾；spec 105、107 行同樣過時 — ✅ 已修：`AGENTS.md` 埠表加「Phase 1 狀態」欄位標示未啟動；spec TCD-4/5/6 加「更正」註記對齊 ruling 3/4/9
6. 計畫 Self-Review 一行仍提到已移除的 `preflight.sh` 的 `PORTS`/`SKIP_DOCKER` — ✅ 核對：目前計畫檔 Self-Review 章節已無此殘留，視為已解決
7. `.planning/codebase/HANDOFF.md` 的探測路徑少了結尾斜線（歷史檔） — ✅ 已修：補上 `/`
8. `MEMORY.md` 同一事實出現兩次（Kandev 前綴） — ✅ 已修：移除重複行
9. `qa-probe.js`、`kandev_bootstrap.py` 寫死絕對路徑／Kandev profile UUID；計畫內的 git 作者信箱含本機主機名 — 🟡 未修（牽涉可攜性，留 Phase 2 計畫評估是否需要）
10. `kandev_bootstrap.py` 沒處理 Kandev 未啟動（`URLError` 直接 traceback） — ✅ 已修：`call()` 補 `except urllib.error.URLError`，印出友善訊息；新增 `test_unreachable_raises_friendly_error`（mock，RED→GREEN 驗證過，不打實機）
11. （我自己的）ledger 對「token 檔為空」的後果寫反：實際是防洩漏檢查失敗閉鎖（誤報），不是靜默通過 — 本列本身即為更正記錄，無需再修
12. 決策記錄的未決項「輪詢 5 秒會不會觸發限流」沒在證據裡結案（審查者查到上限約 20000/duration，實測未見 429） — ✅ 已修：決策記錄改標「已結案」，附讀碼依據 `global/consts.go:30,35`（20000 次/60 秒，5 秒一次遠低於上限）
13. 證據與 ledger 的記憶體數字不同（取樣時間不同） — 不修：屬採樣時間差異，非錯誤

## D. 我代你做的決定（executor rulings，全部可推翻）

1. 文件類直接在 `develop`，程式碼/腳本走 worktree；`.superpowers/` 排除於 git。
2. BE 嵌入模型必經；移除純 golang 備案。
3. 防洩漏改精確比對真實 token。
4. `AGENTS.md`／MEMORY 改寫成「無 AI 服務金鑰，但本地嵌入模型必載」。
5. 對 `*.sh` 用 `git add -f` 指名加入，不改上游 `.gitignore`。
6. `/plan-eng-review` 非互動執行並採建議選項；12 條 ruling 寫入決策記錄；已套用到計畫。
7. `/review` 以手動核心審查代替；未寫 review log。
8. 不合併 `feature/make-env`，Task 6 起用 worktree 路徑呼叫腳本。
9. 不重跑 init。
10. 不改 Dockerfile 去裝 CPU 版 torch，等它下載完。
11. 以 HTTP 200（帶斜線）作就緒訊號，捨棄不存在的 log 標記。
12. 瀏覽器 QA 用 Playwright 精簡流程代替 `/qa-only` 完整流程。
13. 防洩漏掃描改為「token 精確比對＋16/24 位十六進位樣式」，不讀 `docker/.env`。
14. `gsd-extract-learnings` 與 `gsd-pause-work` 以手寫同格式檔案代替；保留 worktree。
15. 最終審查修復輪後不再重審。

## E. 仍待處理（來源：本表）

- ⏳ 核准合併 `feature/make-env`（`cd ~/Taipei-City-Dashboard && git merge --no-ff feature/make-env`），之後 `git worktree remove ~/Taipei-City-Dashboard-worktrees/make-env && git branch -d feature/make-env`
- ❓⏳ 自行驗證管理員登入：`grep DASHBOARD_DEFAULT ~/Taipei-City-Dashboard/docker/.env`
- ⏳ 確認決策記錄的 12 條 ruling 與本表 D 節
- ⏳ 是否設定本機 git `user.name`／`user.email`；是否處理 A11（gstack 升級／routing）
- ❓ A5：Codex 端 80 處 `.claude` 路徑的實際影響
- 🟡 C 節 13 個 Minor：5 項已於 Phase 2 啟動時修掉（5/6/7/8/10/12，共 6 項，見各列狀態）；餘 1–4（`make-env.sh`，待合併）、9（可攜性）留 Phase 2 計畫評估；11、13 無需修
- B21（CUDA torch）、B12（`node_modules`）、B18（PostGIS 模擬）、B27（GA 追蹤）進入 Phase 2 計畫時處理
