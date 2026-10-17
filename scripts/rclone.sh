#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# No iniciar otra instancia mientras mount modifica/refresca el mismo config.
docker compose run --rm --no-deps --entrypoint rclone rclone-mount \
  --config /config/rclone/rclone.conf "$@"
