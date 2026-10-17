#!/bin/sh
set -eu
mounted() { grep -q ' /data/respaldos .* - fuse.rclone ' /proc/self/mountinfo; }
mounted || { echo 'FUSE no disponible: portal bloqueado' >&2; exit 1; }
[ -s /database/filebrowser.db ] || { echo 'Inicializar administrador primero' >&2; exit 1; }
/filebrowser --database /database/filebrowser.db --root /data/respaldos --address 0.0.0.0 --port 8080 &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" || true; exit' TERM INT
while kill -0 "$pid" 2>/dev/null; do
  mounted || { kill -TERM "$pid"; wait "$pid" || true; exit 1; }
  sleep 2
done
wait "$pid"
