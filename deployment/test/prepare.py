#!/usr/bin/env python3
"""Prepare ONLY this loopback test stack. Does not read production secrets."""
import json, os, pathlib, secrets, subprocess
root=pathlib.Path(__file__).resolve().parent
os.chdir(root)
env=root/'.env'
if not env.exists():
    env.write_text('TEST_PASSWORD='+secrets.token_hex(24)+'\n')
    env.chmod(0o600)
password=next(line.split('=',1)[1] for line in env.read_text().splitlines() if line.startswith('TEST_PASSWORD='))
os.environ['TEST_PASSWORD']=password
if os.environ.get('GITHUB_ACTIONS')=='true': print('::add-mask::'+password)
key=root/'secrets'/'oauth.p12'
key.parent.mkdir(exist_ok=True)
if not key.exists():
    # keytool comes from a disposable Java container, not a local Java install.
    subprocess.run(['docker','run','--rm','--env','TEST_PASSWORD',
        '--mount',f'type=bind,source={key.parent},target=/keys',
        '--entrypoint','sh','eclipse-temurin:21-jdk-jammy','-ec',
        'keytool -genkeypair -alias technotes-test-signing -keyalg RSA -keysize 2048 '
        '-storetype PKCS12 -keystore /keys/oauth.p12 -storepass:env TEST_PASSWORD '
        '-keypass:env TEST_PASSWORD -dname CN=TechNotes-Test -validity 30; chmod 644 /keys/oauth.p12'],check=True)
refs=json.loads((root/'versions.json').read_text())
repos={'ui':'technotes-ui','oauth':'technotes-user-oauth-service','notes':'technotes-notes-service','gateway':'technotes-api-gateway'}
for component,repo in repos.items():
    ref=os.environ.get(component.upper()+'_REF') or refs[component]
    folder=root/'sources'/component
    if not folder.exists():
        folder.parent.mkdir(exist_ok=True)
        subprocess.run(['git','clone','--no-checkout','https://github.com/techshakti55/'+repo+'.git',str(folder)],check=True)
    # Never overwrite developers' edits in a test source checkout.
    dirty=subprocess.check_output(['git','-C',str(folder),'status','--porcelain'],text=True)
    if dirty.strip(): raise SystemExit('Test source has local edits: '+component)
    subprocess.run(['git','-C',str(folder),'fetch','origin',ref],check=True)
    subprocess.run(['git','-C',str(folder),'checkout','--detach','FETCH_HEAD'],check=True)
    sha=subprocess.check_output(['git','-C',str(folder),'rev-parse','HEAD'],text=True).strip()
    print(component+' source: '+sha)
print('Test environment prepared. Production was not accessed.')
