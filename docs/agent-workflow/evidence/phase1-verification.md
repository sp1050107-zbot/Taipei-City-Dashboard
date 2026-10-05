# Phase 1 驗收證據

日期：2026-10-06 04:07 CST　分支：develop　基準 commit：ea810ff8
所有輸出均為驗收當下實際執行結果；不含任何密碼或 token。

## 1. 前端（FE）
```
GET http://localhost:8080/ -> 200
title: <title>臺北城市儀表板</title>
```
## 2. 後端（BE）
```
GET :8088/api/v1/dashboard/  -> 200
GET :8088/api/v1/dashboard   -> 301   (無結尾斜線，Gin 轉址；決策記錄 A1)
GET :8080/api/dev/dashboard/ -> 200   (經 Vite 代理)
dashboards by group: {'public': 0, 'taipei': 2, 'metrotaipei': 3, 'personal': 0}
```
## 3. 資料庫
```
dashboard DB tables: 17
dashboard DB 前幾大表（live rows）:
  spatial_ref_sys 8500
  pagc_rules 4354
  bus_info_tpe 3888
  pagc_lex 2938
  bus_info_new_tpe 2836
  city_age_distribution_newtaipei 2160
manager DB tables: 20
  auth_users = 1
  dashboards = 8
  components = 8
  groups = 4
  roles = 3
```
## 4. 管理員
```
auth_users 中的管理員數量: 1
POST /api/dev/auth/login（錯誤帳密）-> 401  （路由存活、拒絕錯誤帳密）
```
**管理後台登入：未驗證（UNVERIFIED）。** 密碼只存在 `docker/.env`，環境的祕密讀取防護禁止代理讀取該檔，所以我沒有以管理員實際登入。請使用者自行在終端機執行 `grep DASHBOARD_DEFAULT docker/.env` 取得帳密後於 `http://localhost:8080` 右上角「登入」驗證。未登入時造訪 `/admin` 會被導回 `/dashboard`（見 QA 結果），表示路由守衛有作用。

## 5. 重跑行為
靜態結論，不實測（決策記錄 A8、A9）：`migrateDB` 使用 GORM AutoMigrate（可重跑）；`initDashboard` 以 `psql -f` 灌入示範資料且無 `ON_ERROR_STOP`，輸出被程式丟棄，重跑可能重複寫入或靜默出錯。init 容器 `Exited (0)` 不代表成功，驗收以第 3 節列數為準。重置：`docker compose -f docker-compose-db.yaml down` 後 `docker volume rm postgres_data postgres_manager_data` 再重新 init。

## 6. 容器、資源與映像
```
dashboard-be	Up 5 minutes
dashboard-fe	Up About an hour
kandev-fork	Up 2 days (healthy)
postgres-data	Up 2 hours
postgres-manager	Up 2 hours
qdrant	Up 2 hours
redis	Up 2 hours

dashboard-be	2.613GiB / 7.748GiB
dashboard-fe	206.8MiB / 7.748GiB
redis	5.086MiB / 7.748GiB
qdrant	99.29MiB / 7.748GiB
postgres-data	31.35MiB / 7.748GiB
postgres-manager	40.11MiB / 7.748GiB
kandev-fork	169.2MiB / 7.748GiB

BE image: dashboard-be-dev:latest 3.01GB
Docker MemTotal: 8319369216 bytes

qdrant/qdrant:latest	sha256:b7b0444c4c351c970b98e90a6f89c2ee4287c65b44e52b4cb503fa5b2aa927ad
golang:1.25.4-bookworm	sha256:e17419604b6d1f9bc245694425f0ec9b1b53685c80850900a376fb10cb0f70cb
postgis/postgis:16-3.4-alpine	sha256:681931a625df344215e9b8998bf34daf146b6a395ceacee4439eb9c85869239f
node:21.6.0-alpine3.18	sha256:1df0c5dfdf73c7ecbcd7fe4b1cd3ce6a0c63b447aa1b6c177fe20575c59f7b72
redis:7.2.3-alpine	sha256:090276da2603db19b154602c374f505d94c10ea57e9749fc3e68e955284bf0fd
```
耗時：FE init（npm ci）約 1 分鐘；兩個 BE init 約 4–9 分鐘（Go 模組下載為主）；BE 首次 build 的 pip 層約 49 分鐘（arm64 解析到 CUDA 版 PyTorch，約數 GB），後因背景指令逾時（我設的 1 小時上限）中斷，重跑時 pip 層命中快取，第二次 build 559 秒完成；`up` 後約 120 秒 BE 才回 200（含 `go run` 編譯與載入 1.1 GB ONNX 模型）。

## 7. 已知差異（預期，不算失敗）
- 台北 3D 建物圖層：`VITE_MAPBOXTILE` 未設定，console 出現 `sources.taipei_building_3d_source: Either "url" or "tiles" is required.`。
- 行政區邊界（`/geo_server/...`）：示範環境沒有。
- PostGIS 映像無 arm64 版，兩個資料庫在 amd64 模擬下運行（`docker compose` 警告）。

## 8. 瀏覽器 QA（gstack `/qa-only` 的報告型原則：只觀察、不修、附證據）
工具：Playwright（gstack 的 `node_modules`）+ 快取的 headless Chromium，**不是** Aside 或內建瀏覽器。探測腳本：`qa/qa-probe.js`（執行：`NODE_PATH=~/gstack/node_modules node qa-probe.js`）。原始結果：`qa/probe-results.json`。截圖：`qa/dashboard.png`、`qa/mapview.png`、`qa/admin.png`。
這是精簡流程：沒有跑 `/qa-only` 的 charter、計時器與探索檢查點，也沒有 Aside。

| 頁面 | 結果 | 證據 |
|---|---|---|
| `/dashboard` | **PASS** | 標題「臺北城市儀表板」；左側列出「臺北儀表板」「雙北儀表板」各群組；圖表有渲染示範資料（長條+折線、行政區地圖、指標卡）；console 錯誤 0；無 4xx 回應。 |
| `/mapview` | **PASS（含預期缺口）** | Mapbox 深色底圖渲染（可見台北各行政區名稱與 `© Mapbox © OpenStreetMap`），代表使用者的 token 有效；canvas 1。console：`User denied Geolocation`（headless 無定位權限，預期）、WebGL 效能警告（無害）、`sources.taipei_building_3d_source: Either "url" or "tiles" is required.`（3D 建物圖層缺 `VITE_MAPBOXTILE`，**預期缺口**）。無 4xx。 |
| `/admin`（未登入） | **PASS** | 被導回 `/dashboard`，路由守衛有作用。 |
| 管理員登入 | **未驗證** | 見第 4 節（祕密讀取防護）。 |

### 額外發現（非缺陷，但值得在 B 階段處理）
- **GA 追蹤外送（P3，confidence 9/10）**：`Taipei-City-Dashboard-FE/index.html:31,39` 載入 Google Tag Manager 並用上游的衡量 ID `G-0KD9XLZ7W3` 呼叫 `gtag("config", ...)`。本機瀏覽時每個頁面都會對 `analytics.google.com/g/collect` 發出請求（本次在 headless 下被 `net::ERR_ABORTED`）。這會把你本機的瀏覽資料送到臺北市的 GA 屬性，也污染對方的統計。建議列為第一批客製：本機環境移除或以環境變數關閉。
- 首次進站會跳出「臺北城市儀表板使用說明」彈窗（正常行為，截圖中可見）。
