import time, urllib.request
targets=['http://localhost:29000/oauth2/jwks','http://localhost:28081/actuator/health',
         'http://localhost:28080/api/v1/public/notes','http://localhost:25173/']
for url in targets:
    deadline=time.monotonic()+180
    while True:
        try:
            with urllib.request.urlopen(url,timeout=5) as response:
                if response.status==200: break
        except Exception: pass
        if time.monotonic()>deadline: raise SystemExit('Readiness failed: '+url)
        time.sleep(2)
    print('READY '+url)
