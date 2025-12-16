#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TS=$(date +%F_%H-%M-%S)

mkdir -p "$BASE_DIR/backups"
tar -czf "$BASE_DIR/backups/manual_stationeers_${TS}.tar.gz" -C "$BASE_DIR/data" .
echo "Backup created: backups/manual_stationeers_${TS}.tar.gz"
