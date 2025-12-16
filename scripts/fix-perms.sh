#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$BASE_DIR/data" "$BASE_DIR/backups"

if command -v chown >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R 1358:1358 "$BASE_DIR/data" "$BASE_DIR/backups"
  else
    chown -R 1358:1358 "$BASE_DIR/data" "$BASE_DIR/backups"
  fi
  echo "OK: data/ and backups/ now belong to UID 1358"
else
  echo "WARN: chown is not available, skipping ownership change"
fi
