# Phase 2 原生開發 runbook(票 09)

資料庫、Redis、Qdrant 留在 Docker;前端(`npm run dev`)與後端(`go run`)在 macOS 主機原生執行。
詞彙見 `GLOSSARY.md`;決定見 `docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md`。

> **同一時間只跑 Phase 1 或 Phase 2 其中一種。** 前端用主機 8080、後端用主機 8088,兩個階段共用同樣的埠。
> 本檔所有指令都在 `~/Taipei-City-Dashboard`(整合 checkout)執行;`docker compose` 只能在這裡跑(規則 7)。
> docker 在這台機器上的路徑是 `~/.docker/bin/docker`。

## 0. 前置條件

| 項目 | 檢查 |
|---|---|
| `docker/.env` 存在(模式 600) | `ls -l docker/.env`(不要印內容) |
| `mapbox-key.txt` 存在 | `ls -l mapbox-key.txt`(不要印內容) |
| `dashboard-be-dev:latest` 映像檔存在 | `docker image ls dashboard-be-dev` |
| 資料庫已初始化(Phase 1) | 不重跑初始化(規則 9) |
| Node 21 | `~/.local/node-v21.7.3/bin/node -v` 應為 `v21.7.3` |
| 後端用本機 Go | `GOTOOLCHAIN=local`(啟動器已設定) |

## 1. 啟動 Phase 2

1. **回顧 Phase 1 期間容器可能動過的檔案**(容器對後端、前端目錄有讀寫權限,見 `/cso` 發現):
   ```bash
   git status --short Taipei-City-Dashboard-BE Taipei-City-Dashboard-FE
   git diff --stat -- Taipei-City-Dashboard-BE Taipei-City-Dashboard-FE
   ```
   出現不認得的變更就停下來檢查,不要往下執行。
   原因:`docker/docker-compose.yaml` 把 `../Taipei-City-Dashboard-BE` 與 `../Taipei-City-Dashboard-FE` 以讀寫方式掛進 Phase 1 容器,容器內的程序可以改寫這兩個目錄的檔案;而 Phase 2 會在主機上直接執行這兩個目錄裡的 `dev-native.sh`、`setup-native-model.sh` 與 `go run`。所以第一次原生執行前,兩個目錄都要看過(每次從 Phase 1 切回來都建議再看一次)。
2. **停掉 Phase 1 的應用容器**(只停,不刪):
   ```bash
   docker stop dashboard-fe dashboard-be
   ```
3. **讓資料與 Redis 容器改成只綁本機埠**(volume 保留,不重跑初始化):
   ```bash
   cd docker && docker compose -f docker-compose-db.yaml up -d redis postgres-data && cd ..
   docker ps --format '{{.Names}} {{.Ports}}' | grep -E 'redis|postgres-data'
   ```
   應看到 `127.0.0.1:6379->6379/tcp` 與 `127.0.0.1:5433->5432/tcp`。
4. **一次性準備後端執行檔**(需要你先核准下載):
   ```bash
   ORT_DOWNLOAD_APPROVED=yes bash Taipei-City-Dashboard-BE/setup-native-model.sh
   ```
   官方 ONNX Runtime 1.23.2 會做 SHA256 驗證;模型從 `dashboard-be-dev:latest` 複製。
5. **前端依賴與本機環境檔**(一次性):
   ```bash
   export PATH="$HOME/.local/node-v21.7.3/bin:$PATH"
   cd Taipei-City-Dashboard-FE && npm ci && bash make-dev-env.sh && cd ..
   ```
   `npm ci` 會把 `node_modules` 換成 macOS 版本;產生 `.env.local` 不會覆蓋、不印出 token。
6. **啟動後端**(終端機 A):
   ```bash
   bash Taipei-City-Dashboard-BE/dev-native.sh
   ```
   若 8088 已被占用,啟動器會拒絕並指向決定 0002。
7. **啟動前端**(終端機 B):
   ```bash
   export PATH="$HOME/.local/node-v21.7.3/bin:$PATH"
   cd Taipei-City-Dashboard-FE && npm run dev
   ```
   前端在 `http://127.0.0.1:8080`;`/api/dev` 代理到 `http://localhost:8088`(可用環境變數 `VITE_LOCAL_BE_URL` 覆蓋)。
8. **就緒探測**:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/api/v1/dashboard/   # 注意結尾斜線
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/
   ```

## 2. 日常開發與計時

- **前端**:改 `src/` 下一行,Vite HMR 應在約 1 秒內更新。驗證者實測 Vite 在存檔後 12 到 103 毫秒推出更新(只量伺服器推送,不含瀏覽器重繪);要量重繪時間請用瀏覽器開發者工具的 Performance。
- **後端**:`go run` 沒有熱重載。改一行後在終端機 A 按 Ctrl-C,再重新執行 `dev-native.sh`;驗證者在 Go 建置快取暖機、原始碼沒有變動時實測 1.15 到 1.78 秒回 200(原始碼有改動時會再加上編譯時間,尚未量測)。
- 中斷點:後端用 IDE 的 Run and Debug(dlv),前端用瀏覽器開發者工具的 Sources。記錄使用的工具。
- 結果寫進 `docs/agent-workflow/evidence/phase2/`。

## 3. 回到 Phase 1

1. 在終端機 A、B 按 Ctrl-C 停掉原生後端與前端。
2. **重建容器用的前端依賴**(Phase 2 的 `npm ci` 把 `node_modules` 換成 macOS 版本,容器會找不到對應的原生模組):
   ```bash
   cd docker && docker compose -f docker-compose-init.yaml up dashboard-fe-init && cd ..
   ```
3. 重新啟動應用容器:
   ```bash
   docker start dashboard-be dashboard-fe
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/api/v1/dashboard/
   ```
4. `redis` 與 `postgres-data` 多開的 `127.0.0.1` 埠不需還原,對 Phase 1 無害。

> **已實測(2026-10-09,擁有者核准後執行)**:先停原生前後端(8080、8088 釋放),再執行第 2 步:`dashboard-fe-init` 輸出 `added 402 packages ... in 17s`、exit 0;`node_modules/@rollup` 只剩 `linux-arm64-gnu` 與 `linux-arm64-musl`(沒有 `darwin`)。第 3 步 `docker start dashboard-be dashboard-fe` 後約 20 秒,後端就緒訊號回 200、前端 200,頁面 0 個 4xx。代價:切回 Phase 2 時要在主機重跑 `npm ci`。
> 切換階段的代價:每次來回都要重裝一次前端依賴。實測(2026-10-09):容器版 `npm ci` 17 秒,主機版 37 秒(都有網路與 npm 快取的前提);切回原生後後端就緒約 3 秒(Go 建置快取暖機),前端 200。

## 4. 已知限制與 UNVERIFIED

- 原生模式**不再代理 `/geo_server`**(Phase 1 容器模式本來就沒有):票 10 的驗證者載入地圖頁時沒有發出 `/geo_server/` 請求,圖層是否空白仍是 UNVERIFIED。
- `REDIS_PASSWORD` 在 `docker/.env` 的值必須與 Redis 容器一致(容器沒有密碼);票 10 確認。
- ONNX Runtime 1.23.2 與 Go 綁定的相容性、Go 1.27.1 編譯與執行、Node 21 在 macOS 上安裝,都以實測為準(票 10)。
- 管理員登入由擁有者本人確認,agent 不登入、不讀密碼。
- Node 21 已停止維護(非 LTS);選它是為了與 `package-lock.json` 的產生環境一致(決定 Q10)。

## 5. 擁有者自行執行的冒煙步驟:後端掛載改唯讀(選用)

票 12 沒有修改 compose 的掛載(離線無法證明唯讀的後端掛載下,容器內的 `go run` 仍能運作,**UNVERIFIED**)。擁有者可在整合 checkout 自行安全地試一次:

1. `cd docker && docker compose stop dashboard-be`
2. 編輯 `docker/docker-compose.yaml`,把後端那一行改成 `- ../Taipei-City-Dashboard-BE:/opt/Taipei-City-Dashboard-BE:ro`。
3. `docker compose up -d dashboard-be`,等候啟動,然後 `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/api/v1/dashboard/`(與第 1 節相同的就緒探測)。
4. 探測回 200 且 `docker logs dashboard-be` 沒有寫入錯誤(例如 read-only file system):保留變更並提交。否則還原該行,再 `docker compose up -d dashboard-be`。

前端掛載(`dashboard-fe`)**必須維持讀寫**:Vite 開發伺服器會把快取寫進自己的目錄(例如 `node_modules/.vite`),唯讀會讓它起不來。
