exec(open('/private/tmp/claude-501/-Users-opsai-Taipei-City-Dashboard/644da2d8-6437-4b39-b1b6-03789720da5e/scratchpad/qa3.py').read().split("ca,ta=tokof")[0])
ca,ta=tokof(env['QA_ADMIN_EMAIL'],env['QA_ADMIN_PASSWORD']);ce,te=tokof(env['QA_EDITOR_EMAIL'],env['QA_EDITOR_PASSWORD'])
body={'user_id':'qa-3','user_name':'qa-3','link':'http://x.example','image':'a.png'}
ids=[]
for i in range(3):
    c,j=show(f'replay admin create contributor #{i+1}',call('POST','/contributor/',body,tok=ta))
    if c==200: ids.append(j['data']['id'])
for i in ids: show('cleanup contributor',call('DELETE',f'/contributor/{i}',tok=ta),200)
# IDOR: editor vs admin's viewpoint (admin user_id 2)
show('admin create vp',call('POST','/user/2/viewpoint',{'center_x':121.5,'center_y':25.0,'zoom':10,'name':'qa-3 admin vp','point_type':'qa-3'},tok=ta))
show('editor READ admin viewpoints',call('GET','/user/2/viewpoint',tok=te))
show('editor CREATE vp for admin',call('POST','/user/2/viewpoint',{'center_x':1,'center_y':1,'zoom':1,'name':'qa-3 idor','point_type':'qa-3'},tok=te))
r=call('GET','/user/2/viewpoint',tok=ta)[1]
for v in r:
    if v['name'].startswith('qa-3'): show('editor DELETE admin vp '+str(v['id']),call('DELETE',f"/user/2/viewpoint/{v['id']}",tok=te))
# cleanup remaining
for u,t in ((2,ta),(3,te)):
    for v in call('GET',f'/user/{u}/viewpoint',tok=t)[1] or []:
        if v['name'].startswith('qa-3'): show(f'cleanup vp {v["id"]}',call('DELETE',f'/user/{u}/viewpoint/{v["id"]}',tok=t))
r=call('GET','/incident/',tok=ta)[1]
print([ (i.get('ID'),i.get('inctype')) for i in r['data']])
