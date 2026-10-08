# Taipei-City-Dashboard 企業級 AI 工作流:技能對照、優缺點與上下文控管

> 狀態:草稿(2026-10-07 已納入 `/ask-matt` 的回答與使用者的 5 項決定,見第 7 節)。依各 repo 的 skill 清單與描述整理,**未逐一試跑**。標「建議」的地方是判斷,不是實測結果。
> 來源專案:Understand-Anything(UA)、gstack、gsd-core、superpowers、mattpocock/skills(下稱 skills)。

## 1. 階段總表(原 8 階段 + 建議新增)

原 8 階段加上 8 個建議新增階段。標 ★ 的是這個專案已經出現過實際問題的階段。

| # | 階段 | 主要技能(每階段只指定一個主力,其餘備選) | 備選 |
|---|---|---|---|
| 0★ | **治理與護欄**(權限、秘密、預算、誰能 push) | gstack `guard` / `careful` / `freeze` | pro-workflow `safe-mode`、skills `git-guardrails-claude-code`(在 misc,未安裝) |
| 1 | 理解 | UA `understand`、`understand-onboard`、`understand-domain` | gsd `gsd-map-codebase`、gsd `gsd-graphify` |
| 2 | 需求與決策 | skills `grill-with-docs` → `to-spec`;大型工作用 `wayfinder` | gstack `office-hours`、`plan-ceo-review`、`spec`;superpowers `brainstorming` |
| 3 | 計畫與交接 | gsd `gsd-discuss-phase` → `gsd-plan-phase`;`gsd-pause-work` / `gsd-resume-work` | superpowers `writing-plans`;skills `to-tickets`、`handoff` |
| 4★ | **安全與威脅建模** | gstack `cso`、gsd `gsd-secure-phase` | superpowers 無對應 |
| 5 | 開發 | superpowers `using-git-worktrees` + `test-driven-development` + `subagent-driven-development` | gsd `gsd-execute-phase`;skills `implement` |
| 6★ | **資料與遷移**(PostGIS、init 容器、種子資料) | 無專屬技能,需自訂 runbook | gsd `gsd-add-tests` 補測試 |
| 7 | 驗證 | superpowers `verification-before-completion` + gstack `review` / `qa` | gsd `gsd-verify-work`、`gsd-code-review`;skills `code-review` |
| 8 | 發布與部署 | gstack `ship` → `land-and-deploy` | gsd `gsd-ship` |
| 9 | 上線後觀測與事故 | gstack `canary`、gsd `gsd-forensics` | gstack `investigate`;superpowers `systematic-debugging` |
| 10 | 維護(除錯、重構、依賴) | superpowers `systematic-debugging`;skills `improve-codebase-architecture` | gsd `gsd-debug`;gstack `investigate`、`health` |
| 11★ | **上游同步與供應鏈**(fork 同步、授權、第三方 token、追蹤碼) | 無專屬技能,需自訂 runbook | gstack `cso` 看依賴 |
| 12 | 自動化 | Kandev workflow + gstack `autoplan`;gsd `gsd-autonomous` | CronCreate / scheduled-tasks |
| 13 | 紀錄與知識管理 | gsd `gsd-extract-learnings`、`gsd-docs-update`;gstack `document-release` | gstack `learn`、`context-save` |
| 14 | **成本與配額管理** | pro-workflow `cost-tracker` | `get_usage` 等工具 |
| 15 | **回顧與流程自評**(評估 agent 本身) | gstack `retro`、`plan-tune` | superpowers `diagnosing-superpowers` |

### 為什麼新增這幾個階段(附本專案實例)

- **治理與護欄**:Kandev 的 `claude-acp` 設定是每個 Bash/Edit 都要人核准;這是護欄,也是 P2-00 卡住的原因。先決定哪些動作允許自動、哪些必須人工。
- **安全**:Phase 1 發現前端 `index.html` 會把使用者資料送到上游的 Google Analytics ID。這類問題要在需求階段就有人檢查,而不是事後才看到。
- **資料與遷移**:init 容器吞掉錯誤,`exit 0` 不代表成功。資料初始化需要自己的驗收項(資料列數),不能靠 exit code。
- **上游同步**:這次實際遇到:gstack 的 fork 與 upstream 歷史不同(見第 5 節),不能盲目 push 或 force-push。
- **成本**:多 agent 並行會同時消耗額度,應有上限與監看。
- **回顧與自評**:要定期評估 agent 本身有沒有遵守規則(P2-00 的 CLAUDE.md 遵守度檢查就是一例)。

## 2. 各技能來源的優缺點

以下優缺點是依 SKILL 描述與已有使用經驗整理的判斷。

| 專案 | 優點 | 缺點 | 最適合階段 |
|---|---|---|---|
| **superpowers** | 紀律強:先設計再計畫、TDD、完成前要驗證證據;子 agent 用乾淨上下文執行單一任務;技能少而聚焦(15 個) | 沒有部署、瀏覽器 QA、跨 session 狀態;不管上線後 | 開發、驗證 |
| **gstack** | 覆蓋從點子到部署再到回顧的完整鏈;有安全護欄(`guard`、`careful`、`freeze`);有瀏覽器 QA 與 `cso` 安全審查;可呼叫 Codex 做第二意見 | 技能多且重;偏作者的工作風格(YC 創辦人視角);更新快,版本與 fork 同步有成本;部分功能依賴額外服務(gbrain 等) | 需求決策、驗證、發布、回顧 |
| **gsd-core** | 狀態與交接做得最完整(`.planning/`、phase、pause/resume、workstreams);可自主跑完多個 phase;有健康檢查與事後鑑識 | 儀式多,小任務太重(有 `gsd-fast` / `gsd-quick` 補救);72 個技能,描述佔上下文;與其他框架的規劃功能重疊 | 計畫、交接、紀錄 |
| **skills(mattpocock)** | 小、可組合、可改;`grill-with-docs` 在寫程式前逼出決策並留下 ADR;`wayfinder` 處理「一個 session 裝不下」的大工作;有 `ask-matt` 路由 | 沒有部署與營運;依賴 issue tracker 設定(要先跑 `setup-matt-pocock-skills`);部分在 `in-progress` | 需求、計畫 |
| **Understand-Anything** | 把程式碼變成知識圖譜,可查影響範圍(`understand-diff`);新人 onboarding 快;你的 fork 還多了 `graph-query` | 不是工作流,只是知識層;大型 repo 建圖耗時與額度;圖會過期,要重建 | 理解、維護 |

## 3. 重疊與衝突(實際盤點)

- 同名技能:`retro`、`handoff`、`tdd`、`domain-modeling` 在多個來源都有。這次補裝 mattpocock/skills 時,這 4 個我**沒有連結**,避免覆蓋你既有的 gstack `retro` 與 pro-workflow `tdd` / `domain-modeling`。
- 規劃類技能至少 5 套:superpowers `writing-plans`、gsd `gsd-plan-phase`、gstack `plan-eng-review` / `autoplan`、skills `to-spec` / `to-tickets`、pro-workflow `plan-interrogate`。**建議每個專案只選一條規劃主線**,否則不同 agent 會產生互相矛盾的計畫。
- 本機目前 `~/.claude/skills` 約 177 項、`~/.agents/skills` 約 159 項。每個 session 都會載入這些技能的名稱與描述,這是固定的上下文成本。

## 4. 同時跑多 agent、多 LLM、多 worktree:避免上下文滿載與幻覺

「幻覺」在這個專案不是抽象風險:Phase 1 的文件把 `router.go` 的行號寫成 137(實際 138–139),還複製進三份文件,是被另一個 session 重跑才抓到。下面的做法都針對這類問題。

### 4.1 每個任務的邊界

1. **一個任務 = 一個 session = 一個 worktree = 一個 Kandev 卡片**。不要讓一個長 session 同時做多件事。
2. **子 agent 只拿「任務簡報」,不繼承主對話**。簡報包含:目標、要讀的檔、不准碰的檔、驗收指令。
3. **並行上限**:同時 3 到 4 個執行中的 agent。超過後審核與合併的人力會先成為瓶頸,而不是模型速度。
4. **共享資源只有一個擁有者**:Taipei 的 compose 使用固定的 `container_name`,所以只有整合 checkout 能跑 compose,worktree 不能啟動容器。同理,port、資料庫、`.env` 都要指定唯一擁有者。

### 4.2 單一事實來源,取代長對話

| 檔案 | 內容 | 規則 |
|---|---|---|
| `CLAUDE.md` / `AGENTS.md` | 規則與角色路由 | 保持短,細節用 `@import` 拆開 |
| `MEMORY.md` | 已知坑與狀態索引 | 一條一行,過期就刪 |
| `.planning/` | phase 計畫與 HANDOFF | 交接檔固定五個標題 |
| `docs/agent-workflow/phase*-issue-log.md` | 問題與決定 | 只追加,不改寫 |
| `evidence/` | 指令輸出與截圖 | 文件中的數字必須能指到這裡 |

### 4.3 防幻覺規則

1. **宣稱要附證據**:任何「已完成 / 已通過」都要貼指令與輸出(`verification-before-completion`)。文件裡的行號、數字、版本要能由指令重現。
2. **生成者與驗證者分開**:執行的 session 不自己驗收。審查與驗收固定由 **Codex 擔任獨立驗證者**(唯讀,只審不修;見 `docs/decisions/0004-codex-independent-review-and-cross-verification.md`);Claude 自己的 `/code-review`、`/review`、`/cso` 只是前置自檢,不能取代這一關。Claude 也反向驗證 Codex:採納每條結論前先查證原碼或輸出。
3. **引用先查證**:引用檔案與行號前先 `grep -n` 確認。
4. **標示不確定**:無法驗證的項目寫 UNVERIFIED,不要寫成通過(Phase 1 的管理員登入就是這樣處理)。
5. **不信任自述**:檢查 commit、diff、測試輸出,而不是 agent 的總結。

### 4.4 上下文預算

- 主 session 只做協調與決策,大量讀檔、搜尋、跑測試交給子 agent,只收回結論。
- 在 60% 到 70% 左右主動 `/compact` 或寫 handoff,不要等到被迫壓縮(gsd 有 context monitor hook,pro-workflow 有 `compact-guard`)。
- 大檔案用範圍讀取、log 先 `tail` 或過濾再讀。
- 技能依角色白名單載入,不是全域 177 個都開。例如「驗證角色」只需要 `verification-before-completion`、`review`、`qa`。
- 切換主題就開新 session,不要在同一個 session 裡堆積不相關背景。

### 4.5 多 LLM 分工建議

| 角色 | 建議 | 理由 |
|---|---|---|
| 決策、規劃 | 最強模型 | 錯誤成本最高 |
| 大量執行、重複修改 | 中等模型 + 嚴格測試 | 有測試擋住錯誤 |
| 審查、驗收 | **固定 Codex(獨立驗證者,唯讀);Claude 自檢只是前置** | 避免同源偏差;結論由 Claude 反向查證 |
| 搜尋、盤點 | 較小模型 | 成本低、只回結論 |

### 4.6 Worktree 衛生

- Kandev 會替每個任務自動建立 worktree 與分支。目前有 `feature/p1-01` 到 `p1-08` 閒置,建議定期清理(清理前先確認沒有未合併的 commit)。
- 每個 worktree 只允許改程式碼,文件在整合 checkout 的 `develop` 上直接改,避免合併衝突(P2-00 與文件修正就差點衝突)。
- `.serena/` 等工具暫存要加進 `.git/info/exclude`。

### 4.7 階段邊界決策樹(來自 `/ask-matt` 的 `PHASE-BOUNDARIES.md`)

在**兩個階段之間**(不是做到一半)依序問,第一個「是」就採用:

1. **能繼續嗎?** 下一階段要用這階段當第一手資料,或 smart zone(約 150k token)還有空間 → 繼續。
2. **內容與下一步無關?** → `/clear`。
3. **要換 harness(Claude→Codex)、換目錄、給同事、或中途分出支線?** → `/handoff`(落地規則見第 7 節決定 3)。
4. **能放給 AFK 子 agent?** → 子 agent(例如自動審查)。
5. **否則** → `/compact`,附一句指示說明下一階段要保留什麼。它是預設,不是第一個選項。

除 Continue 外,每個動作都會把第一手資料變成有損的摘要,所以先問能不能繼續。

### 4.8 多 agent 並行的實際做法(skills 的任務圖)

`/grill-with-docs → /to-spec → /to-tickets` 在**同一個不中斷的上下文**完成;每張票是帶阻擋關係的垂直切片,大小可裝進一個全新上下文。之後:
- 一張一張做:`/implement`,每張之間 `/clear`。
- 整份 spec 一次做:`/implement-spec`,把票當**任務圖**,對「前線」(阻擋已完成的票)平行派實作子 agent,各自在自己的 worktree 跑 `/tdd`,merger 子 agent 合併到**一條整合分支**,最後對整合分支跑一次 `/code-review`。子 agent 之間只傳**脈絡指標**(spec、票、研究筆記、commit 路徑),不複製內容。

## 5. 附記:gstack fork 的 377 個 commit(2026-10-07 調查)

- `sp1050107-zbot/gstack` 確實是 `garrytan/gstack` 的 fork。
- 上游在 2026-09-15 的 v1.87.4.0 把歷史壓成一個根 commit,本地 clone 的歷史因此只有 33 個 commit。
- 你的 fork 保留了完整歷史,所以 `origin/main` 有 377 個本地沒有的 commit:約 333 個 Garry Tan、17 個 `t`、其餘是其他貢獻者與你自己的 2 個(`0d6b400e` 文件模板修改與一次 merge)。這些都是上游早期歷史,不是你的私有修改。
- 2026-10-07 你的 fork 已經與上游合併到 v1.91.33.0,**目前 `origin/main` 與 `upstream/main` 的檔案內容完全相同**。
- 結論:**不要 force-push**(會刪掉完整歷史與你的 2 個 commit)。本地分支只需要對齊 `origin/main`。

## 6. 新增 8 階段的工作流程

**把握度標示**:
- ✅ 已讀該技能的 SKILL.md,技能做什麼與步驟有依據。
- ⚠️ 技能存在,但「怎麼套到 Taipei」是我的判斷,尚未試跑。
- ❓ 沒有對應技能或我無法確認,**需要你執行 `/ask-matt` 取得意見**(該技能設定為只有使用者能叫用,我不能代為呼叫,也不會模擬它)。

Taipei 的前提:目前只有本機 Docker、沒有線上環境、不對上游 push。下面凡牽涉「線上」的步驟,都是等你有部署目標之後才適用。

### 6.1 治理與護欄 ✅

**目的**:決定哪些動作 agent 可自動做、哪些要人核准,並讓這件事由機制執行,不靠 prompt 提醒。

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | 已有的靜態規則:`AGENTS.md` 的 9 條(worktree、不 push、不碰祕密、compose 只在整合 checkout) | 本專案 |
| 2 | 危險指令警告:`/careful`(`rm -rf`、`DROP TABLE`、`git push -f`、`git reset --hard`、`docker system prune` 等) | gstack `careful` |
| 3 | 限制可編輯範圍:`/freeze <目錄>`,範圍外的 Edit/Write 會被**擋掉**,不只警告;兩者合用是 `/guard` | gstack `freeze`、`guard` |
| 4 | 在 worktree 派工時,把 freeze 目錄設成該 worktree | 判斷 ⚠️ |
| 5 | 權限提示太多時用 pro-workflow `permission-tuner` 產生規則,減少人工核准疲勞 | pro-workflow |
| 6 | 定期用 `mcp-audit` 檢查 MCP 的 token 負擔與安全 | pro-workflow |

**閘門**:任何 push、合併到 `develop`、刪 volume,都要人核准。
**已有實例**:這個環境的 hook 已經擋下 `git reset --hard`,權限分類器也拒絕了 `git checkout -B`,代表護欄在運作;但它們擋的是「指令形狀」,不會判斷意圖,所以仍要人看。

### 6.2 安全與威脅建模 ✅(`cso`)/ ⚠️(套用方式)

**目的**:在寫程式前後都有人檢查攻擊面、祕密、依賴、授權。

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | 計畫階段:在 spec 加「威脅」小節,至少列祕密(`mapbox-key.txt`、`docker/.env`)、對外資料流(前端 GA 追蹤碼)、管理員登入 | Phase 1 實例 ⚠️ |
| 2 | 每個 phase 完成後:`gsd-secure-phase` 對照計畫中的威脅檢查緩解措施是否真的存在 | gsd ✅ |
| 3 | 合併前:`/cso --diff`(只看本次分支變更的靜態審查,不執行應用) | gstack `cso` ✅ |
| 4 | 每月或大版本:`/cso`(全範圍);`--supply-chain` 專看依賴;`--infra` 看 Docker/部署設定 | gstack `cso` ✅ |
| 5 | 需要實際重現時才用 `/cso --comprehensive`,它需要符合的「已驗證 runtime profile」,Go + Vue 是否在清單內我沒確認 | ❓ |
| 6 | 發現的問題要用 `--recheck` 重新查證,關閉要有新證據 | gstack `cso` ✅ |

**閘門**:`cso` 有 High 以上未處理,不得合併。
**注意**:`cso` 是靜態審查,不能證明沒有漏洞。

### 6.3 資料與遷移(沒有專屬技能;已諮詢 `/ask-matt`)

`/ask-matt` 的答覆:**沒有專屬的遷移技能**。可用的組合:

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | `/diagnosing-bugs`:先建立**會在這個問題上變紅**的單一指令(例如資料列數不對就失敗),再修 | skills ✅ |
| 2 | 遷移腳本當一般功能做:`/grill-with-docs → /to-spec → /to-tickets → /implement`(內含 `/tdd`),用測試擋住「重跑重複寫入」 | skills ✅ |
| 3 | 先在**拋棄式 volume** 跑,通過再用在正式 volume;遷移前 `pg_dump`,回滾步驟寫進 runbook | 判斷 ⚠️ |
| 4 | 修完跑 `/retro`,把「init 吞錯」這類**機械性錯誤**變成確定性檢查(如 `ON_ERROR_STOP`、CI 檢查),不要只靠提示詞 | skills ✅ |
| 5 | 只有**必須由人操作**的步驟(填憑證、點第三方後台)才用 `/wizard`;agent 自己能做的不要用 | skills ✅ |
| 6 | 驗收證據存進 `evidence/` | 既有慣例 |

不該做:不要用 `/wizard` 取代自動化的遷移腳本。

### 6.4 發布與部署 ✅(技能)/ ⚠️(套用)

**前提**:Taipei 目前沒有線上環境。repo 有 `helm-chart/` 和 `k8s` 相關檔案,但我沒有驗證它們可用。

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | 一次性:`/setup-deploy`,它偵測部署平台、正式網址、健康檢查,並把設定寫進 `CLAUDE.md`。**沒有部署目標時不要跑** | gstack ✅ |
| 2 | 合併前:`/ship`(合併 base、跑測試、審查 diff、更新 VERSION 與 CHANGELOG、push、開 PR)。**注意 `/ship` 會 push,與 AGENTS.md 規則 3 衝突,必須由你明確授權** | gstack ✅ |
| 3 | `/land-and-deploy`:合併 PR、等 CI 與部署、做 canary 驗證、必要時回復(Step 8)、產出部署報告 | gstack ✅ |
| 4 | **本機版本(目前實際適用)**:worktree 通過驗證 → 本機 merge 回 `develop` → 在整合 checkout 重建並起容器 → 跑冒煙測試(FE/BE 狀態碼、`/api/v1/dashboard/`、資料列數) | 本專案 Phase 1 ✅ |

**閘門**:任何 push 或遠端合併都要你明確同意。
**`/ask-matt` 的答覆**:這些技能裡沒有部署或發布技能;能對應的只有 `/implement-spec` 的結尾(整合分支、`/code-review`)與 `/pr`(PR 內文:最小視覺、前後證據、單向門或雙向門判斷)。
**目前定義(判斷 ⚠️,非 Matt 的流程)**:整合分支通過 `/code-review` ＋ Codex 審查 → 本機合併到 `develop` → 在整合 checkout 重建並通過冒煙測試,才算「發布完成」。有線上環境後再加 `setup-deploy` 與 `land-and-deploy`。

### 6.5 上線後觀測與事故 ✅(技能)/ ⚠️(套用)

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | 部署前先 `/canary --baseline`:對每個頁面擷取基準截圖、console 錯誤、效能 | gstack `canary` ✅ |
| 2 | 部署後 `/canary`:定期截圖並與基準比較,異常時警示 | gstack `canary` ✅ |
| 3 | 事故中:`/investigate`(找根因)或 superpowers `systematic-debugging` | ✅ |
| 4 | 難重現的問題:skills `diagnosing-bugs`(核心是**先建立可穩定重現的回饋迴圈**,並要求先遮蔽祕密) | skills ✅ |
| 5 | 事後:`gsd-forensics` 診斷失敗的工作流;事故紀錄寫進 issue log | gsd ✅ |

**限制**:`canary` 是瀏覽器層級的監看,不是伺服器端指標(沒有 metrics/log 平台)。Taipei 目前沒有這類平台。
**`/ask-matt` 的答覆**:本機**不需要獨立的事故流程**,也沒有對應技能。出問題走 `/diagnosing-bugs`,修完在同一個 session 跑 `/retro`,問「什麼可以預防它」;若結論是「沒有好的接縫可以鎖住」,轉 `/improve-codebase-architecture`。有線上環境後再補值班與回復流程(那時才用 `canary`)。

### 6.6 上游同步與供應鏈(沒有現成技能;已諮詢 `/ask-matt`)

**已有實例**:這次同步 5 個 fork,其中 gstack 的 fork 與上游歷史不同,不能直接 push 或 force-push。

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | `git fetch upstream`,比較 `behind/ahead`,並看 `merge-base` 與歷史是否被上游重寫 | 本次實作 ✅ |
| 2 | 能 fast-forward 才 ff;分叉時先比樹狀內容(本次 `origin` 與 `upstream` 內容相同,所以只需對齊) | 本次實作 ✅ |
| 3 | **永遠不 force-push**,除非你明確指示並接受歷史被刪 | 規則 ⚠️ |
| 4 | 上游更新後:`/cso --supply-chain --diff` 檢查新增依賴與授權 | gstack ✅ |
| 5 | 檢查第三方 token(Mapbox)與追蹤碼(GA `G-0KD9XLZ7W3`)是否仍存在 | Phase 1 實例 ⚠️ |
| 6 | 把同步結果與決定寫進 issue log | 既有慣例 |

**`/ask-matt` 的答覆**:**沒有適合的技能,不建議硬湊**。唯一可借用的是 `/research`:派背景 agent 查「上游為什麼壓縮歷史」並留下有引用的 Markdown,它只幫查資料,不是同步流程。同步本身是一般 git 紀律(上面步驟 1 到 3)。

### 6.7 成本與配額 ⚠️

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | session 內用 pro-workflow `cost-tracker` 查花費、設預算警示 | pro-workflow ✅ |
| 2 | 平行 agent 數上限 3 到 4,避免同時耗用額度 | 第 4.1 節 ⚠️ |
| 3 | 把重複大量讀檔的工作交給子 agent,主 session 只收結論 | 第 4.4 節 ⚠️ |
| 4 | 每個 Kandev 任務在描述中寫預算(模型、最多幾輪) | 判斷 ⚠️ |
| 5 | 每週用 `/retro`(見 6.8)查看用量趨勢 | ⚠️ |

**限制**:我沒有確認 Kandev 本身是否提供每任務用量統計。

### 6.8 回顧與流程自評 ✅

| 步驟 | 做法 | 依據 |
|---|---|---|
| 1 | 每週 `/retro`:分析 commit 歷史、工作模式與程式品質指標,保留歷史並看趨勢 | gstack `retro` ✅ |
| 2 | agent 遵守度檢查:像 P2-00 那樣,逐條對照 `CLAUDE.md` / `AGENTS.md`,**用 commit、diff 與測試輸出,不用 agent 自述** | 本專案實例 ✅ |
| 3 | session 出問題(重複工作、忽略計畫、花太多)時:superpowers `diagnosing-superpowers` | superpowers ✅ |
| 4 | 調整提問頻率:`/plan-tune`(檢視哪些提問會觸發,設定「不再問」或「一律問」) | gstack ✅ |
| 5 | 學到的事:gstack `learn`、gsd `gsd-extract-learnings`;規則有變就更新 `MEMORY.md` 與 `AGENTS.md` | ✅ |
| 6 | 每個里程碑結束:gsd `gsd-audit-milestone` 對照原始意圖 | gsd ✅ |

注意:`retro` 在 gstack 與 skills 各有一個,本機只有 gstack 的版本被連結。

## 7. `/ask-matt` 的回答與已定案決定(2026-10-07)

### 7.1 `/ask-matt` 摘要

| 問題 | 答覆 |
|---|---|
| 1 資料遷移 | 沒有專屬技能;見 6.3 |
| 2 發布 | 沒有發布技能;見 6.4 的目前定義 |
| 3 事故 | 本機不需要獨立流程;見 6.5 |
| 4 上游同步 | 沒有適合技能;見 6.6 |
| 5 多 agent | 用階段邊界決策樹(4.7)與 `/to-tickets` + `/implement-spec` 任務圖(4.8);`/wayfinder` 只給巨大且迷霧中的工作;`/chief-of-staff` 在 in-progress,屬實驗;`/handoff` 僅在換 harness、換目錄、給同事、中途分支時用 |

**避免規劃類技能重疊**:規劃主線只選一條(skills 的 `grill-with-docs → to-spec → to-tickets`,或 gsd 的 `discuss → plan-phase`);開發的 TDD 用 superpowers 或 `/implement` 內建的 `/tdd`;gstack 的 `plan-eng-review`、`review`、`cso` 當**閘門**,不當第二套規劃;同專案內交接用 `.planning/`,換 harness 才用 `/handoff`。

### 7.2 使用者的 5 項決定與落地

| # | 決定 | 落地 |
|---|---|---|
| 1 | Matt 的 engineering 流程先跑 `/setup-matt-pocock-skills`;tracker 選 Kandev | **使用者要自己執行**(該技能不能由 agent 叫用)。tracker 回答方式見 7.3 |
| 2 | 本機 tracker 寫 `.scratch/<feature>/issues/` | `AGENTS.md` 規則 2 白名單已加入 `.scratch/`、`GLOSSARY.md`、`docs/agents/` |
| 3 | `/handoff` 與規則 6 對齊 | 規則 6 已改:`/handoff` 產出要複製到 `.planning/handoffs/<日期>-<主題>.md` 並 commit,交接以已 commit 的路徑為準 |
| 4 | ADR 與決策放 `docs/decisions/` | `AGENTS.md` 新增「追蹤與領域文件」:不建立 `docs/adr/`,`GLOSSARY.md` 在根目錄,同一決定只寫一處 |
| 5 | 規則 1 接受 `/implement-spec` 自動開多 worktree 並合併 | 規則 1 已加例外:子 agent worktree 合併到同一條整合分支,通過 `/code-review` ＋ Codex 審查與驗證後,才一次 merge 回 `develop`;子 worktree 要清理 |

### 7.3 執行 `/setup-matt-pocock-skills` 時怎麼回答

該技能會依序問,以下是建議回答。

**Section A:Issue tracker** 它會提供四個選項:GitHub、GitLab、本機 markdown(`.scratch/`)、Other(自述)。
- 因為你的決定是「Kandev + 本機 `.scratch/`」,選 **Other**,並貼上這段描述:

> Tickets and specs are local markdown files: spec at `.scratch/<feature>/spec.md`, one ticket per file at `.scratch/<feature>/issues/<NN>-<slug>.md` with a `Blocked by:` line and a `Status:` line. Each ticket has exactly one card on the Kandev board (http://127.0.0.1:38429, workspace taipei-city-dashboard) whose description contains only the ticket's file path, never a copy of its content. Claiming a ticket means starting a Kandev session on its card and setting `Status: claimed` in the file. Resolving means appending the answer to the file, setting `Status: resolved`, and moving the card to Done. The file is the source of truth; the card is only a pointer. Do not use GitHub Issues; origin must not receive pushes without explicit user approval.

- 為什麼不選 GitHub:你的規則 3 禁止未經同意的 push,而且 origin 只是 fork,GitHub Issues 會把任務散到第二個地方。
- 為什麼不單選「本機 markdown」:你要 Kandev 當看板,所以需要 Other 把「卡片只指向檔案」寫清楚,避免兩處內容不一致。

**Section B:Triage labels** 只有安裝了 `triage` 才會問。問「是否保留預設標籤?」建議 **yes**(`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`)。它們會寫成票內的 `Status:` 文字,不會建立 GitHub 標籤。

**Section C:Domain docs** 預設是單一上下文(`GLOSSARY.md` + `docs/adr/`),**不會問你**,所以你要在 Step 3「確認並編輯」時,把 `docs/agents/domain.md` 草稿裡的 `docs/adr/` 全部改成 `docs/decisions/`。

**Step 3 與 Step 4**:它會把 `## Agent skills` 區塊寫進 `CLAUDE.md`(因為已存在)。你的 `CLAUDE.md` 有 100 行上限(`check-docs.sh` 會檢查),目前約 25 行,沒問題。

### 7.4 仍然開放的事

- `docs/decisions/` 的既有檔名是 `0001-...md`,與 Matt 的 ADR 範例格式相同,可直接沿用。
- `GLOSSARY.md` 尚未建立;`/grill-with-docs` 會在需要時產生,不必先建。
- 目前沒有 `.planning/handoffs/` 目錄,第一次用 `/handoff` 時再建立。
- P2-00 分支(`feature/p2-00-phase-2-far`)也改了 `AGENTS.md`(埠號表),之後合併可能衝突,但改動位置不同,應該能自動合併。
