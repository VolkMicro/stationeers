#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

# Перед обновлением — ручной бэкап (на всякий)
./scripts/backup-now.sh || true

docker compose build --no-cache
docker compose up -d
docker compose ps
