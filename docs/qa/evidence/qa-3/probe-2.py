"""票 01（viewpoint 越權）與票 02（contributor 序號）的重現與跨使用者探測。

用法：python3 probe-2.py        （從任何目錄執行；只依賴同目錄的 qa_lib.py）
副作用：建立帶 qa-3 的 contributor 與 viewpoint；全部在 finally 內用 API 刪除，不留資料。
修正後預期：editor 對 admin 的讀、建、刪皆 403（票 01）。
"""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from qa_lib import *

def main():
    ca,ta=tokof(env['QA_ADMIN_EMAIL'],env['QA_ADMIN_PASSWORD']);ce,te=tokof(env['QA_EDITOR_EMAIL'],env['QA_EDITOR_PASSWORD'])
    admin_id=call('GET','/user/me',tok=ta)[1]['user']['user_id']
    editor_id=call('GET','/user/me',tok=te)[1]['user']['user_id']
    contributors=[];viewpoints=[]   # (user_id, viewpoint_id, token)
    try:
        body={'user_id':'qa-3','user_name':'qa-3','link':'http://x.example','image':'a.png'}
        for i in range(3):
            c,j=show(f'create contributor #{i+1}',call('POST','/contributor/',body,tok=ta))
            if c==200: contributors.append(j['data']['id'])
        vp={'center_x':121.5,'center_y':25.0,'zoom':10,'name':'qa-3 admin vp','point_type':'qa-3'}
        c,j=show('admin create vp',call('POST',f'/user/{admin_id}/viewpoint',vp,tok=ta))
        if c in(200,201): viewpoints.append((admin_id,j['data']['id'],ta))
        show('editor READ admin viewpoints',call('GET',f'/user/{admin_id}/viewpoint',tok=te))
        c,j=show('editor CREATE vp for admin',call('POST',f'/user/{admin_id}/viewpoint',dict(vp,name='qa-3 idor'),tok=te))
        if c in(200,201): viewpoints.append((admin_id,j['data']['id'],ta))
        if viewpoints:
            show('editor DELETE admin vp',call('DELETE',f'/user/{admin_id}/viewpoint/{viewpoints[0][1]}',tok=te))
        show('editor create own vp',call('POST',f'/user/{editor_id}/viewpoint',dict(vp,name='qa-3 own'),tok=te))
    finally:
        for cid in contributors: call('DELETE',f'/contributor/{cid}',tok=ta)
        for uid in (admin_id,editor_id):
            tok=ta if uid==admin_id else te
            for v in (call('GET',f'/user/{uid}/viewpoint',tok=tok)[1] or []):
                if isinstance(v,dict) and str(v.get('name','')).startswith('qa-3'):
                    call('DELETE',f'/user/{uid}/viewpoint/{v["id"]}',tok=tok)

if __name__=='__main__':
    main()
