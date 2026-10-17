#!/bin/sh
set -eu
exec rclone mount union-onedrive: /data/respaldos \
  --config /config/rclone/rclone.conf \
  --password-command 'cat /run/secrets/rclone_password' \
  --allow-other --uid 1000 --gid 1000 --umask 007 \
  --vfs-cache-mode writes --cache-dir /cache \
  --vfs-cache-max-size 20G --vfs-cache-min-free-space 2G \
  --vfs-cache-max-age 24h --vfs-write-back 5s \
  --dir-cache-time 5m --poll-interval 1m \
  --buffer-size 16M --transfers 4 --log-level INFO
