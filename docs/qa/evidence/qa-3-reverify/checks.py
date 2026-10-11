import sys,os,json
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
