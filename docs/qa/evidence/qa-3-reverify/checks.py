"""票 01、03 的運行中複驗檢查（匿名／非管理者／本人）。

安全限制（Codex 審查後加入）：
- 只能對「沒有設定 Airflow 網址」或「已套用票 03 修正」的後端執行。對未修正、又設有 AIRFLOW_SUMMARY_BASE_URL 的後端，
  匿名與 editor 的 POST /component/ai-summary/trigger 會真的觸發 DAG。
- 絕不用管理者呼叫 trigger（本腳本也不會）。
- 必須明確指定目標，否則拒絕執行：
    QA_API_BASE=http://127.0.0.1:8089/api/v1 QA_CONFIRM_NO_AIRFLOW=1 python3 checks.py
  QA_CONFIRM_NO_AIRFLOW=1 表示你已確認目標符合上面的條件。
- 本腳本不建立任何資料（建資料的是 ../qa-3/probe-2.py）。
"""
import os,sys
if not os.environ.get('QA_API_BASE') or os.environ.get('QA_CONFIRM_NO_AIRFLOW')!='1':
    sys.exit('拒絕執行：請設定 QA_API_BASE 與 QA_CONFIRM_NO_AIRFLOW=1（見檔頭說明）。')
import json
sys.path.insert(0,os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','qa-3'))
from qa_lib import *
ca,ta=tokof(env['QA_ADMIN_EMAIL'],env['QA_ADMIN_PASSWORD']);ce,te=tokof(env['QA_EDITOR_EMAIL'],env['QA_EDITOR_PASSWORD'])
j='{}'
body={'index':'qa-3-noindex','city':'taipei','type':'chart'}
print('base',B)
show('anon POST trigger',call('POST','/component/ai-summary/trigger',body),403)
show('anon GET status',call('GET','/component/ai-summary/status/qa-3-x'),403)
show('editor POST trigger',call('POST','/component/ai-summary/trigger',body,tok=te),403)
show('editor GET status',call('GET','/component/ai-summary/status/qa-3-x',tok=te),403)
show('anon POST /component/ (admin ctl)',call('POST','/component/',{'name':'qa-3'}),403)
c,r=call('GET','/component/ai-summary?index=youbike_availability&city=taipei&type=chart'); print('GET /ai-summary public ->',c,str(r)[:90])
eid=call('GET','/user/me',tok=te)[1]['user']['user_id']
show('editor delete own nonexistent vp (expect 404)',call('DELETE',f'/user/{eid}/viewpoint/999999',tok=te),404)
show('admin READ editor viewpoints (no admin bypass)',call('GET',f'/user/{eid}/viewpoint',tok=ta),403)
show('anon GET viewpoint',call('GET',f'/user/{eid}/viewpoint'),403)
show('editor own list',call('GET',f'/user/{eid}/viewpoint',tok=te),200)
