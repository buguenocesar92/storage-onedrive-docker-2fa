#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
v=dict(l.split('=',1) for l in Path('.env').read_text().splitlines() if l and not l.startswith('#'))
p=Path('config/authelia/users_database.yml')
with p.open('x') as f:
 json.dump({'users':{v['ADMIN_USER']:{'displayname':'Administrador','password':sys.stdin.read().strip(),'email':v['ADMIN_EMAIL'],'groups':['storage-admins']}}}, f, indent=2)
os.chown(p,0,1000); p.chmod(0o640)
