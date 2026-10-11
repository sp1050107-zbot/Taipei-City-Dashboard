"""QA 探測共用函式（自給自足，不依賴任何 session 暫存檔）。

需要：python3、本機後端 http://127.0.0.1:8088、`~/.qa-secrets/taipei-qa.env`
（不在 repo；內含 QA_ADMIN_EMAIL／QA_ADMIN_PASSWORD／QA_EDITOR_EMAIL／QA_EDITOR_PASSWORD）。
token 與密碼不會被輸出。
"""
import json,os,base64,urllib.request,urllib.error
B=os.environ.get('QA_API_BASE','http://127.0.0.1:8088/api/v1')
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
