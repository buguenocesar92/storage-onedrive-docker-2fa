#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
umask 077
fail() { echo "ERROR: $*" >&2; exit 1; }
for cmd in docker python3 mount mountpoint findmnt; do command -v "$cmd" >/dev/null || fail "Falta $cmd"; done
docker compose version >/dev/null
docker info >/dev/null
[[ $(uname -s) == Linux && -c /dev/fuse ]] || fail 'Requiere Linux nativo/VM Linux con /dev/fuse (modprobe fuse)'
[[ $EUID == 0 ]] || fail 'Ejecutar sudo ./setup.sh; necesita preparar propagación FUSE'
[[ -f .env ]] || cp .env.example .env
case "${1:-help}" in
  prepare)
    mkdir -p secrets data/{cache,mounts/respaldos,filebrowser,authelia,caddy} runtime/{authelia,caddy}
    chmod 700 secrets data/cache data/caddy
    chmod 755 data data/mounts runtime
    chown 1000:1000 data/filebrowser data/authelia
    chmod 700 data/filebrowser data/authelia
    # El directorio subyacente es inaccesible al UID del portal si desaparece FUSE.
    if ! mountpoint -q data/mounts/respaldos; then
      [[ -z $(find data/mounts/respaldos -mindepth 1 -maxdepth 1 -print -quit) ]] || fail 'Directorio base no vacío'
      chown root:root data/mounts/respaldos
      chmod 000 data/mounts/respaldos
    fi
    mountpoint -q data/mounts || mount --bind "$PWD/data/mounts" "$PWD/data/mounts"
    mount --make-rshared "$PWD/data/mounts"
    python3 - <<'PY'
import secrets, os
from pathlib import Path
for name in ('rclone_password','session_key','storage_key','jwt_key'):
 p=Path('secrets')/name
 if not p.exists(): p.write_text(secrets.token_hex(48)+'\n')
p=Path('secrets/smtp_password')
if not p.exists(): p.write_text('')
for p in Path('secrets').iterdir():
 os.chown(p,0,1000); p.chmod(0o440)
PY
    [[ -f config/rclone/rclone.conf ]] || cp config/rclone/rclone.conf.example config/rclone/rclone.conf
    chmod 700 config/rclone
    chmod 600 config/rclone/rclone.conf .env
    echo 'Preparado. Editar .env, configurar/cifrar rclone e inicializar admin (README).'
    ;;
  render)
    python3 scripts/render.py
    chown root:1000 runtime/authelia runtime/authelia/configuration.yml
    ;;
  admin)
    [[ ! -e config/authelia/users_database.yml && ! -e data/filebrowser/filebrowser.db ]] || fail 'Usuario/base ya existe; no se sobrescribe'
    echo 'Genera el hash Argon2 de la contraseña de Authelia (prompt interactivo):'
    auth_image=$(python3 -c 'from pathlib import Path; print(dict(l.split("=",1) for l in Path(".env").read_text().splitlines() if l and not l.startswith("#"))["AUTHELIA_IMAGE"])')
    docker run --rm -it --entrypoint authelia "$auth_image" crypto hash generate argon2
    read -r -p 'Pega solamente el hash $argon2id$...: ' admin_hash
    [[ $admin_hash == '\$argon2id\$'* ]] && fail 'Pegar hash sin backslashes'
    [[ $admin_hash == '$argon2id$'* ]] || fail 'Hash inválido'
    printf '%s' "$admin_hash" | python3 scripts/create-user.py
    unset admin_hash
    docker compose build storage-portal
    # La contraseña aleatoria de File Browser no autentica: auth proxy es obligatorio.
    docker compose run --rm --no-deps --entrypoint /filebrowser storage-portal config init --database /database/filebrowser.db
    docker compose run --rm --no-deps --entrypoint /filebrowser storage-portal config set --database /database/filebrowser.db --auth.method=proxy --auth.header=Remote-User
    admin_user=$(python3 -c 'from pathlib import Path; print(dict(l.split("=",1) for l in Path(".env").read_text().splitlines() if l and not l.startswith("#"))["ADMIN_USER"])')
    random_password=$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')
    docker compose run --rm --no-deps --entrypoint /filebrowser storage-portal users add "$admin_user" "$random_password" --database /database/filebrowser.db --perm.admin --scope .
    unset random_password
    ;;
  validate)
    docker compose config --quiet
    docker compose run --rm --no-deps --entrypoint authelia authelia validate-config --config /config/configuration.yml
    docker compose run --rm --no-deps auth-proxy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    ;;
  up)
    [[ -s config/authelia/users_database.yml && -s data/filebrowser/filebrowser.db ]] || fail 'Falta inicializar admin'
    grep -q '^RCLONE_ENCRYPT_V0:' config/rclone/rclone.conf || fail 'Cifrar rclone.conf antes de iniciar'
    findmnt -n -o PROPAGATION --target "$PWD/data/mounts" | grep -q shared || fail 'Ejecutar prepare después de reiniciar host'
    "$0" render
    "$0" validate
    docker compose up -d --build
    ;;
  *) echo 'Uso: sudo ./setup.sh {prepare|render|admin|validate|up}';;
esac
