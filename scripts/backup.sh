#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

docker compose run --rm \
  -e RUN_ONCE=1 \
  backup
