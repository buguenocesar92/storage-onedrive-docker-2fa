#!/usr/bin/env python3
"""Render configuration from a deliberately restricted dotenv format; never eval."""
import json, os, re
from pathlib import Path
os.umask(0o077)
root = Path(__file__).resolve().parent.parent
values = {}
for line in (root / '.env').read_text().splitlines():
    if not line.strip() or line.lstrip().startswith('#'): continue
    key, sep, value = line.partition('=')
    if not sep or not re.fullmatch(r'[A-Z_]+', key): raise SystemExit('Formato .env inválido')
    values[key] = value
v = values
mode = v['MODE']
if mode not in ('lab', 'production'): raise SystemExit('MODE inválido')
for key in ('BASE_DOMAIN','PORTAL_HOST','AUTH_HOST'):
    if not re.fullmatch(r'[a-z0-9]+(?:[a-z0-9.-]*[a-z0-9])?',v[key]): raise SystemExit('Dominio inválido')
for key in ('PORTAL_HOST','AUTH_HOST'):
    if not v[key].endswith('.' + v['BASE_DOMAIN']): raise SystemExit('Hosts deben compartir BASE_DOMAIN')
if v['PORTAL_HOST'] == v['AUTH_HOST']: raise SystemExit('Hosts deben ser distintos')
if not re.fullmatch(r'[a-z][a-z0-9_-]{0,31}',v['ADMIN_USER']): raise SystemExit('ADMIN_USER inválido')
if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+',v['ADMIN_EMAIL']): raise SystemExit('Email inválido')
if v['HTTPS_PORT'] != '443' or v['HTTP_PORT'] != '80':
    raise SystemExit('Esta configuración HTTPS requiere puertos 80/443 (URLs de cookies sin puertos alternos)')
if mode == 'lab' and v['BIND_IP'] != '127.0.0.1': raise SystemExit('Laboratorio restringido a 127.0.0.1; usar túnel SSH')
if mode == 'production' and (v['BASE_DOMAIN'].endswith('.test') or 'example.com' in v['SMTP_ADDRESS'] or not (root/'secrets/smtp_password').read_text().strip()):
    raise SystemExit('Producción requiere dominios reales y SMTP configurado')
auth = {
 'server': {'address':'tcp://0.0.0.0:9091/'},
 'log': {'level':'info'},
 'totp': {'disable':False,'issuer':'Storage Backup','algorithm':'SHA1','digits':6,'period':30,'skew':1},
 'webauthn': {'disable':True},
 'duo_api': {'disable':True},
 'authentication_backend': {'password_reset':{'disable':True},'file':{'path':'/users/users_database.yml','watch':False}},
 'access_control': {'default_policy':'deny','rules':[{'domain':v['PORTAL_HOST'],'subject':['group:storage-admins'],'policy':'two_factor'}]},
 'session': {'name':'storage_session','same_site':'lax','inactivity':'5m','expiration':'1h','remember_me':'-1','cookies':[{'domain':v['BASE_DOMAIN'],'authelia_url':'https://'+v['AUTH_HOST'],'default_redirection_url':'https://'+v['PORTAL_HOST']}]},
 'regulation': {'max_retries':5,'find_time':'2m','ban_time':'15m'},
 'storage': {'local':{'path':'/var/lib/authelia/db.sqlite3'}},
 'notifier': {'filesystem':{'filename':'/var/lib/authelia/notification.txt'}}
}
if mode == 'production':
    auth['notifier'] = {'smtp':{'address':v['SMTP_ADDRESS'],'username':v['SMTP_USERNAME'],'sender':v['SMTP_SENDER'],'password':(root/'secrets/smtp_password').read_text().strip()}}
# JSON is valid YAML; escaping avoids config injection through dotenv.
p = root/'runtime/authelia/configuration.yml'; p.parent.mkdir(parents=True,exist_ok=True)
p.write_text(json.dumps(auth,indent=2)+'\n'); p.chmod(0o640)
# Root-owned config readable by the unprivileged container via gid 1000.
p.parent.chmod(0o750)
tls = 'tls internal' if mode == 'lab' else ''
caddy = '''AUTH_HOST {
  TLS
  header X-Content-Type-Options nosniff
  reverse_proxy authelia:9091
}
PORTAL_HOST {
  TLS
  header {
    X-Content-Type-Options nosniff
    X-Frame-Options DENY
    Referrer-Policy no-referrer
  }
  route {
    request_header -Remote-User
    request_header -Remote-Groups
    request_header -Remote-Email
    request_header -Remote-Name
    forward_auth authelia:9091 {
      uri /api/authz/forward-auth
      copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
    reverse_proxy storage-portal:8080
  }
}
'''.replace('AUTH_HOST',v['AUTH_HOST']).replace('PORTAL_HOST',v['PORTAL_HOST']).replace('TLS',tls)
p = root/'runtime/caddy/Caddyfile'; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(caddy)
print('Configuración generada. Modo:',mode)
