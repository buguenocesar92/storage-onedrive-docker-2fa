#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $EUID == 0 && -d data/mounts/respaldos ]] || exit 1
mountpoint -q data/mounts || mount --bind "$PWD/data/mounts" "$PWD/data/mounts"
mount --make-rshared "$PWD/data/mounts"
