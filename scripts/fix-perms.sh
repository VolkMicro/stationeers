#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$BASE_DIR/data" "$BASE_DIR/backups"
sudo chown -R 1358:1358 "$BASE_DIR/data" "$BASE_DIR/backups"
echo "OK: permissions fixed for data/ and backups/ (UID 1358)"
