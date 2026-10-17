#!/usr/bin/env python3
"""Static invariants. Requires PyYAML; not a substitute for Docker/E2E tests."""
import json
from pathlib import Path
import yaml
root = Path(__file__).resolve().parent.parent
c = yaml.safe_load((root/'docker-compose.yml').read_text())
assert c['networks']['net-storage']['internal'] is True
assert [k for k,v in c['services'].items() if 'ports' in v] == ['auth-proxy']
p = c['services']['storage-portal']
assert p['networks'] == ['net-storage']
assert p['user'] == '1000:1000'
assert p['read_only'] and p['cap_drop'] == ['ALL']
assert p['volumes'][1]['bind']['propagation'] == 'rslave'
assert c['services']['rclone-mount']['volumes'][3]['bind']['propagation'] == 'rshared'
a = json.loads((root/'runtime/authelia/configuration.yml').read_text())
assert a['access_control']['default_policy'] == 'deny'
assert all(r['policy'] == 'two_factor' for r in a['access_control']['rules'])
assert not a['totp']['disable']
s = (root/'runtime/caddy/Caddyfile').read_text()
assert s.index('request_header -Remote-User') < s.index('forward_auth') < s.index('reverse_proxy storage-portal')
print('PASS: static isolation, mount propagation, TOTP and header ordering')
