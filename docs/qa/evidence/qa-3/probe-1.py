import json,os,base64,urllib.request,urllib.error
B='http://127.0.0.1:8088/api/v1'
env=dict(l.strip().split('=',1) for l in open(os.path.expanduser('~/.qa-secrets/taipei-qa.env')) if '=' in l)
def call(m,p,body=None,tok=None,basic=None):
    h={'Content-Type':'application/json'}
    if tok:h['Authorization']='Bearer '+tok
    if basic:h['Authorization']='Basic '+base64.b64encode(basic.encode()).decode()
    r=urllib.request.Request(B+p,method=m,headers=h,data=json.dumps(body).encode() if body is not None else None)
    try:
        x=urllib.request.urlopen(r,timeout=20);c=x.status;t=x.read()
    except urllib.error.HTTPError as e:c=e.code;t=e.read()
    try:j=json.loads(t)
    except Exception:j=t.decode()[:100]
    return c,j
def tokof(e,p):
    c,j=call('POST','/auth/login',basic=f'{e}:{p}');return c,(j.get('token') if isinstance(j,dict) else None)
def show(name,res,exp=None):
    c,j=res
    s=json.dumps(j,ensure_ascii=False)[:150] if not (isinstance(j,dict) and 'token' in j) else '<token redacted>'
    flag='' if exp is None else (' OK' if c==exp else f' **EXPECTED {exp}**')
    print(f'{name}: {c}{flag} {s}')
    return res
ca,ta=tokof(env['QA_ADMIN_EMAIL'],env['QA_ADMIN_PASSWORD']);ce,te=tokof(env['QA_EDITOR_EMAIL'],env['QA_EDITOR_PASSWORD'])
print('login',ca,ce)
show('login wrong pw',call('POST','/auth/login',basic=env['QA_ADMIN_EMAIL']+':wrong'),401)
show('login bad email fmt',call('POST','/auth/login',basic='notanemail:x'),401)
show('bad token /user/me',call('GET','/user/me',tok='abc'),None)
r=show('admin /user/me',call('GET','/user/me',tok=ta),200)
show('editor /user/me',call('GET','/user/me',tok=te),200)
show('editor GET /user/ (admin only)',call('GET','/user/',tok=te),403)
r=show('admin GET /user/',call('GET','/user/',tok=ta),200)
show('editor GET /incident/',call('GET','/incident/',tok=te),403)
show('admin GET /incident/',call('GET','/incident/',tok=ta),200)
show('editor GET /issue/',call('GET','/issue/',tok=te),403)
show('admin GET /issue/',call('GET','/issue/',tok=ta),200)
show('admin check-index',call('GET','/dashboard/check-index/qa-3-x',tok=ta),200)
show('editor check-index',call('GET','/dashboard/check-index/qa-3-x',tok=te),403)
# personal dashboard
c,j=show('editor create personal dash',call('POST','/dashboard/',{'name':'qa-3 dash','icon':'star','components':[60]},tok=te),200)
idx=j['data']['index'] if c==200 else None
if idx:
    show('editor get own dash',call('GET','/dashboard/'+idx,tok=te),200)
    show('editor patch own dash',call('PATCH','/dashboard/'+idx,{'name':'qa-3 dash2','icon':'star','components':[60,212]},tok=te),200)
    show('admin2 patch editor dash (other owner)',call('PATCH','/dashboard/'+idx,{'name':'x','icon':'star','components':[60]},tok=ta),None)
    show('anon delete dash',call('DELETE','/dashboard/'+idx),403)
    show('editor delete own dash',call('DELETE','/dashboard/'+idx,tok=te),200)
    show('get deleted dash',call('GET','/dashboard/'+idx,tok=te),404)
show('editor create dash missing fields',call('POST','/dashboard/',{'name':''},tok=te),400)
show('editor create public dash (admin only)',call('POST','/dashboard/public?city=taipei',{'index':'qa-3-pub','name':'qa-3 pub','icon':'star','components':[60]},tok=te),403)
c,j=show('admin create public dash',call('POST','/dashboard/public?city=taipei',{'index':'qa-3-pub','name':'qa-3 pub','icon':'star','components':[60]},tok=ta),200)
pidx=j['data']['index'] if c==200 else None
if pidx:
    show('anon list shows pub',(lambda r:(r[0],[d['index'] for d in r[1]['data']['taipei']]))(call('GET','/dashboard/')))
    show('admin delete public dash',call('DELETE','/dashboard/'+pidx,tok=ta),200)
# contributor
show('editor create contributor',call('POST','/contributor/',{'user_id':'qa-3','user_name':'qa-3','link':'http://x.example','image':'a.png'},tok=te),403)
c,j=show('admin create contributor',call('POST','/contributor/',{'user_id':'qa-3','user_name':'qa-3','link':'http://x.example','image':'a.png'},tok=ta),200)
cid=(j.get('data') or {}).get('id') if c==200 and isinstance(j,dict) else None
if cid:
    show('admin patch contributor',call('PATCH',f'/contributor/{cid}',{'user_id':'qa-3','user_name':'qa-3b','link':'http://x.example'},tok=ta),200)
    show('admin delete contributor',call('DELETE',f'/contributor/{cid}',tok=ta),200)
# issue
c,j=show('editor create issue',call('POST','/issue/',{'title':'qa-3 issue','user_name':'qa-editor','user_id':'qa-editor','description':'qa-3','context':''},tok=te),200)
iid=j['data']['id'] if c==200 else None
show('anon create issue',call('POST','/issue/',{'title':'qa-3','user_name':'a','user_id':'a','description':'a'}),403)
show('issue missing fields',call('POST','/issue/',{'title':''},tok=te),400)
if iid: show('admin patch issue',call('PATCH',f'/issue/{iid}',{'status':'closed','decision_desc':'qa-3'},tok=ta),200)
# incident
c,j=show('admin create incident',call('POST','/incident/',{'inctype':'qa-3','description':'qa-3','distance':10,'latitude':25.03,'longitude':121.56,'status':'open'},tok=ta),200)
show('incident missing fields',call('POST','/incident/',{'inctype':''},tok=ta),400)
# viewpoint
uid=json.dumps(call('GET','/user/me',tok=te)[1])[:0]
me=call('GET','/user/me',tok=te)[1]
eid=(me.get('user') or me.get('data') or {}).get('user_id') if isinstance(me,dict) else None
print('editor user_id',eid)
if eid:
    c,j=show('editor create viewpoint',call('POST',f'/user/{eid}/viewpoint',{'center_x':121.5,'center_y':25.0,'zoom':10,'pitch':0,'bearing':0,'name':'qa-3 vp','point_type':'qa-3'},tok=te),200)
    show('editor list viewpoint',call('GET',f'/user/{eid}/viewpoint',tok=te),200)
    show('admin read editor viewpoints (cross-user)',call('GET',f'/user/{eid}/viewpoint',tok=ta),None)
    show('PATCH me',call('PATCH','/user/me',{'name':'qa-editor'},tok=te),200)
# component admin
show('editor create component',call('POST','/component/',{'name':'qa-3'},tok=te),403)
show('anon component create',call('POST','/component/',{'name':'qa-3'}),403)
