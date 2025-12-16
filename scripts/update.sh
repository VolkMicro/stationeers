#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

# Пересобираем образ и перезапускаем сервис
docker compose build --pull
docker compose up -d
docker compose ps
