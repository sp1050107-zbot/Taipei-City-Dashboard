# 03: ai-summary/trigger 未掛管理者驗證，匿名可觸發 DAG

**What to build:** 只有系統管理者能 POST `/component/ai-summary/trigger` 與 GET `/component/ai-summary/status/:dag_run_id`；匿名回 403。`GET /component/ai-summary` 維持公開。

**Blocked by:** None (can start immediately)

**Status:** resolved

**Read first (nothing else is assumed):** `AGENTS.md`、`docs/qa/README.md`，以及本票列出的證據。

## Bug

- 發現於：`docs/qa/runs/2026-10-11-3.md`　環境：`develop` @ `92c8057d`，Phase 1 容器
- 嚴重度：S2　所屬層：後端；已實測（2026-10-11，擁有者同意）：匿名請求越過驗證到達 handler
- 重現步驟：
  1. 讀 `router.go` 的 `configureComponentRoutes`：`IsSysAdm()` 在 `componentRoutes.Use(...)` 之後才生效，而 `/ai-summary/trigger` 在它之前註冊。
  2. 驗證時（需擁有者同意觸發 DAG）：不帶 token POST `/api/v1/component/ai-summary/trigger`，body `{"index":"qa-3","type":"chart"}`。
- 預期：403。
- 實際（實測）：匿名 POST 回 502「Failed to connect to Airflow service ... unsupported protocol scheme」，表示已越過驗證並進入 handler；同組管理者路由（POST `/component/`、PATCH `/component/60`）匿名回 403。匿名 GET `/ai-summary/status/<id>` 同樣到達 handler。
- **前提（Codex 審查補充）**：只有設定了 `AIRFLOW_SUMMARY_BASE_URL` 的部署，匿名者才真的能觸發 DAG；預設為空字串，此時回 502、不會觸發。範圍含 trigger 與 status 兩條路由。
- 限制：本環境 Airflow `BaseURL` 未設定，所以沒有真的建立 DAG run；實際觸發能力依 Airflow 設定。送的是不存在的 index（`qa-3-noindex`），未留下 Airflow 執行紀錄。部署若設了 Airflow，匿名者即可用服務帳號觸發 DAG。
- 證據：`docs/qa/evidence/qa-3/ticket-03-anon-trigger.txt`
- 候選檔案：
  - `Taipei-City-Dashboard-BE/app/routes/router.go:114` — 路由註冊順序（來源：讀碼）
  - `Taipei-City-Dashboard-BE/app/controllers/componentAISummary.go:86` — handler（來源：讀碼）
- 影響範圍：endpoint `POST /api/v1/component/ai-summary/trigger`、`GET /api/v1/component/ai-summary/status/:dag_run_id`（改成只限系統管理者，匿名與非管理者 403）；`GET /api/v1/component/ai-summary` 維持公開；頁面：管理後台組件設定（`Taipei-City-Dashboard-FE/src/components/dialogs/admin/AdminComponentSettings.vue`，本來就只有管理者使用）；測試：`app/routes/router_test.go`（用替身 Airflow）
- 退回次數：0

## Acceptance criteria

- [x] 先寫出能重現本 bug 的失敗測試（無法用測試重現時，說明改用哪種證據）。
- [x] 修復後該測試通過，既有測試仍全部通過。
- [x] 影響範圍已填。
- [ ] 合併前通過 `/code-review` 與 Codex 獨立審查（`docs/decisions/0004-…`）。
- [x] 由另一個 session 複驗：原重現步驟與影響範圍的回歸項目都通過，證據已存。

## Answer

已修正並併入 `develop`：`917e92a2`（分支 `feature/qa-01-03-authz` @ `46b3d0aa`，未 push）。作者是 Taipei｜主線，驗收是 Taipei｜QA。

- 修法：`/ai-summary/trigger` 與 `/ai-summary/status/:dag_run_id` 移到 `IsSysAdm()` 子群組（`registerAISummaryRoutes`），`GET /ai-summary` 維持公開。
- 測試：用 Gin httptest 搭替身 Airflow，修正前匿名與非管理者都打到了 Airflow（各 2 次，RED），修正後 0 次；管理者仍可呼叫替身。**從頭到尾沒有打真的 Airflow**（大里決定「票 03 先不測」）。
- 複驗：Taipei｜QA 報告 `docs/qa/runs/2026-10-11-5.md`（離線層 PASS）、`2026-10-11-6.md`（8089：匿名與 editor 都 403；對照 8088 上的 develop 版本回 502；QA 分支 `356e1db3`）。沒有測「管理者仍可 trigger」對真的 Airflow。
- 審查：Codex 唯讀 GATE: PASS（併入前）。`/code-review` 是**併入後才補跑**的，所以對應的驗收條件保持未勾選。補跑結果：Standards 沒有違反書面規範；Spec 沒有實作錯誤。
- 後續（不阻擋，未修）：沒有測試鎖住「`GET /component/ai-summary` 維持公開」。
- 8088 的原生後端已在併入後重啟：匿名 POST trigger 回 403，在驗證那一層就擋下，請求沒有送到 Airflow。
