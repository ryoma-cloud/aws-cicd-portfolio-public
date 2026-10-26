"""Reproducible ZIPs from one lock, Linux CI runtime, bundled TLS trust."""
import hashlib
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
import urllib.request

from tools.paths import TEMP_ROOT as ROOT

# 固定日時・並び順で依存ライブラリとLambdaをZIP化し、SHA-256のmanifestをローカル生成する。AWSへは配布しない。
def build():
    builddir=ROOT/'terraform'/'build';builddir.mkdir(parents=True,exist_ok=True)
    certdir=ROOT/'app/certs';certdir.mkdir(exist_ok=True)
    cert=certdir/'global-bundle.pem'
    if not cert.exists():
        cert.write_bytes(urllib.request.urlopen('https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem',timeout=30).read())
    staging=builddir/'staging'
    if staging.exists():shutil.rmtree(staging)
    staging.mkdir()
    subprocess.run([sys.executable,'-m','pip','install','--disable-pip-version-check','-q','-r',str(ROOT/'app/requirements.lock'),'--target',str(staging)],check=True)
    shutil.copytree(ROOT/'app/common',staging/'common',ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copytree(certdir,staging/'certs')
    manifest={}
    for name in ('employee_intake','employee_register','request_batch','transfer_result','resend','id_mock'):
        output=builddir/(name+'.zip')
        with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(staging.rglob('*')):
                if path.is_file() and '__pycache__' not in path.parts:
                    info=zipfile.ZipInfo(path.relative_to(staging).as_posix(),(2020,1,1,0,0,0))
                    archive.writestr(info,path.read_bytes(),compress_type=zipfile.ZIP_DEFLATED)
            info=zipfile.ZipInfo('app.py',(2020,1,1,0,0,0))
            archive.writestr(info,(ROOT/'lambda/id_system_simulator/handler.py' if name=='id_mock' else ROOT/'lambda'/name/'app.py').read_bytes())
        manifest[name]=hashlib.sha256(output.read_bytes()).hexdigest()
    (builddir/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

if __name__=='__main__':build()
