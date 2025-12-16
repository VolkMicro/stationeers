#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

# Перед обновлением бэкапы отключены — вернём позже, когда сервер заработает стабильно

docker compose build --no-cache
docker compose up -d
docker compose ps
