#!/usr/bin/env bash
set -euo pipefail
# CA_CERT opcional para laboratorio. No se desactiva validación TLS.
: "${PORTAL_URL:?Ejemplo: PORTAL_URL=https://files.storage.test}"
args=()
[[ -z ${CA_CERT:-} ]] || args+=(--cacert "$CA_CERT")
for path in / /api/resources/ /api/raw/test /share/test; do
  for user in '' admin; do
    code=$(curl "${args[@]}" --silent --show-error --max-time 15 -o /dev/null -w '%{http_code}' -H "Remote-User: $user" "$PORTAL_URL$path")
    case "$code" in 302|303|401|403) ;; *) echo "FAIL $path: HTTP $code (esperaba bloqueo de autenticación)"; exit 1;; esac
  done
done
echo 'OK: sin sesión, rutas protegidas incluso con Remote-User falsificado.'
