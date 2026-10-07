# 只靠單一專案維護 Taipei-City-Dashboard:各自的使用流程

> 狀態:草稿。流程依各 repo 的 skill 描述整理,**未逐一試跑**,試跑前請當成起點而非保證。
> 問題:如果只用 superpowers、gstack、gsd-core、skills 其中一個(加上它自己的 subagent 與 loop),夠不夠維護 Taipei-City-Dashboard?

## 結論先看

| 專案 | 單獨是否足夠 | 補不到的地方 |
|---|---|---|
| gstack | **最接近完整**:需求到部署到回顧都有 | 紀律與跨 session 狀態較弱;技能重、更新快 |
| gsd-core | **規劃、交接、驗收足夠**,可自主跑多個 phase | 瀏覽器 QA、設計審查、部署後監看較弱 |
| superpowers | **開發階段足夠**,紀律最好 | 沒有部署、營運、跨 session 狀態 |
| skills(mattpocock) | **需求到實作足夠**,適合小步前進 | 沒有部署與營運 |
| Understand-Anything | **不能單獨使用**,它只提供程式碼理解 | 全部工作流 |

共通缺口:Taipei 的資料初始化、Docker 環境、fork 同步、第三方 token 管理,沒有任何專案提供專屬技能,都要靠自己的 runbook(見 `enterprise-workflow-skill-map.md` 第 1 節)。

---

## A. 只用 superpowers

**子 agent 與 loop 能力**:`subagent-driven-development`(每個任務一個乾淨 agent,完成後做規格與品質審查)、`dispatching-parallel-agents`(獨立任務並行)。

**新功能或修改**
1. `brainstorming`:釐清需求與設計,產出 spec。
2. `using-git-worktrees`:建立隔離 worktree。
3. `writing-plans`:寫逐步計畫。
4. `subagent-driven-development`(或在不能開子 agent 時用 `executing-plans`):每個任務 TDD 實作,逐任務審查。
5. `requesting-code-review` → `receiving-code-review`。
6. `verification-before-completion`:貼出測試與指令輸出。
7. `finishing-a-development-branch`:選擇合併、PR 或保留。

**修 bug**
1. `systematic-debugging`:先找根因再修。
2. `test-driven-development`:先寫會失敗的測試。
3. `verification-before-completion` → `finishing-a-development-branch`。

**缺口與補法**:部署與上線後觀測自己寫 runbook;跨 session 交接靠 plan 檔與 commit 紀錄。

---

## B. 只用 gstack

**子 agent 與 loop 能力**:`autoplan`(依序跑 CEO、設計、工程、DX 審查並自動決定)、`codex`(呼叫 OpenAI Codex 做第二意見)、`guard` / `careful` / `freeze`(護欄)。

**新功能**
1. `office-hours`:釐清要做什麼、為什麼。
2. `plan-ceo-review` → `plan-eng-review`(涉及介面再加 `plan-design-review`、`plan-devex-review`),或直接 `autoplan` 一次跑完。
3. 實作(gstack 本身不規定 TDD,測試要求寫在 `plan-eng-review` 與 `ship` 的檢查裡)。
4. `review`:合併前審查 diff。
5. `qa`(會修)或 `qa-only`(只回報):用真瀏覽器驗 FE 流程,對 Taipei 的儀表板頁、地圖頁、管理頁很實用。
6. `cso`:安全審查。
7. `ship`:合併 base、跑測試、審查、更新 VERSION 與 CHANGELOG、push、開 PR。
8. `land-and-deploy` → `canary`:合併部署並做上線後監看。
9. `document-release`、`retro`、`learn`:文件、回顧、記下學到的事。

**修 bug**:`investigate` → `qa` → `ship`。

**跨 session**:`context-save` / `context-restore`。

**缺口與補法**:狀態檔不如 gsd 結構化;技能多、說明長,上下文成本高,建議只開用到的。

---

## C. 只用 gsd-core

**子 agent 與 loop 能力**:`gsd-autonomous`(對剩餘 phase 自動跑 discuss→plan→execute)、`gsd-manager`(單一終端管理多個 phase)、`gsd-workstreams`(平行工作流)、`gsd-next` / `gsd-progress`(判斷下一步);另有 `gsd-executor`、`gsd-verifier`、`gsd-code-reviewer`、`gsd-plan-checker` 等專職 agent。

**首次接手**
1. `gsd-map-codebase`:平行 mapper 產出 `.planning/codebase/`。
2. `gsd-new-project`(或 `gsd-ingest-docs` 匯入既有文件)建立 PROJECT 與 ROADMAP。

**每個 phase**
1. `gsd-discuss-phase`:針對這個 phase 釐清決策(必要時 `gsd-spec-phase`、`gsd-ui-phase`)。
2. `gsd-plan-phase`:研究 + 計畫 + 計畫檢查。
3. `gsd-execute-phase`:依相依分 wave 並行執行,每個任務原子 commit。
4. `gsd-code-review`、`gsd-verify-work`、`gsd-secure-phase`、`gsd-add-tests`。
5. `gsd-ship`:開 PR。
6. `gsd-extract-learnings`、`gsd-docs-update`。

**小任務**:`gsd-fast`(不開子 agent)、`gsd-quick`。**修 bug**:`gsd-debug`(狀態可跨 context 重置);出事後用 `gsd-forensics`。

**暫停與接手**:`gsd-pause-work` → `gsd-resume-work`;不確定時 `gsd-next`。**健康檢查**:`gsd-health`。

**缺口與補法**:沒有瀏覽器 QA 與部署後監看,需要自己補。儀式較多,小改動用 `gsd-fast`。

---

## D. 只用 skills(mattpocock)

**子 agent 與 loop 能力**:`wayfinder`(把超過單一 session 的工作拆成決策票逐一解決)、`chief-of-staff`(in-progress,用子 agent 協調長期目標)、`implement`(依 spec 或票實作)。`ask-matt` 可問該用哪個技能。

**第一次**:`setup-matt-pocock-skills`(設定 issue tracker 與慣例)。

**新功能**
1. `grill-with-docs`:逐題訪談,同時產出 ADR 與詞彙表。
2. `to-spec`:寫成 spec。
3. `to-tickets`:拆成帶阻擋關係的追蹤票(tracer-bullet)。
4. `implement` 或 `implement-spec`。實作時用 `codebase-design` 的詞彙檢視模組介面。
5. `code-review`、`pr`。

**修 bug**:`diagnosing-bugs` → 修 → `code-review`。**issue 整理**:`triage`。**資料查詢**:`research`(查官方文件並存成 Markdown)。**交接**:`handoff`(本機因同名沒有連結,見下)。

**缺口與補法**:沒有部署、營運、瀏覽器 QA。這個專案的 `tdd`、`handoff`、`retro`、`domain-modeling` 因與既有技能同名,沒有連結到 `~/.claude` 或 `~/.agents`;需要時用該專案內的路徑 `~/skills/skills/...` 直接讀。

---

## E. Understand-Anything(輔助層)

不是獨立工作流。搭配上面任一套:
- 接手時:`understand` 建圖 → `understand-onboard` 產 onboarding。
- 改動前:`understand-diff` 看影響範圍;`understand-explain` 解釋指定檔案或函式。
- 業務脈絡:`understand-domain`。
- 你的 fork 多了 `graph-query`(鏈與影響查詢)和 `augment-gin-vue`(補 Gin 端點與 Vue import,對 Taipei 的 Go + Vue 結構特別有用)。

---

## 建議

不要同時啟用五套規劃主線。對 Taipei-City-Dashboard,實務上可選:

- **簡單**:gstack 當骨幹(決策到部署),開發階段借 superpowers 的 TDD;gsd 只拿來做交接與紀錄。這正是 `CLAUDE.md` 目前寫的三層分工。
- **最少依賴**:只用 gsd-core,瀏覽器 QA 另用 gstack `qa-only`。

選定後,把不用的規劃類技能從該角色的白名單移除,減少上下文成本與互相矛盾的計畫。
