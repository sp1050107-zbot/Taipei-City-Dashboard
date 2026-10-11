# qa-3 證據說明

- `probe-1.out`、`probe-2.out`：第 3 次巡檢（2026-10-11）當時的輸出，由當時 session 暫存目錄的腳本產生。
- `probe-1.py`、`probe-2.py`、`qa_lib.py`：同一批探測整理成可在任何 checkout 執行的版本（相依只有同目錄的 `qa_lib.py` 與本機 `~/.qa-secrets/taipei-qa.env`），並加上清除資料（finally）。**整理後的腳本沒有重跑**（避免再動共用資料），只做了語法與 import 檢查；`.out` 與新腳本的逐行輸出可能略有差異（例如 contributor 序號已越過衝突區）。
- `ticket-03-anon-trigger.txt`：票 03 的匿名請求紀錄。
- issue 沒有刪除端點；probe-1 結束時會印出手動清除的 SQL。
