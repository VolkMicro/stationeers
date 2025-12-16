#!/bin/bash
set -euo pipefail

: "${INSTALL_DIR:=/opt/stationeers}"
: "${DATA_DIR:=/data}"
: "${SERVER_USER:=rocket}"
: "${SERVER_BINARY:=/opt/stationeers/rocketstation_DedicatedServer.x86_64}"

ensure_data_dir() {
  mkdir -p "${DATA_DIR}"
  chown -R "${SERVER_USER}:${SERVER_USER}" "${DATA_DIR}"
}

run_server() {
  cd "${INSTALL_DIR}"
  exec gosu "${SERVER_USER}" env \
    HOME="${DATA_DIR}" \
    "${SERVER_BINARY}" "$@"
}

ensure_data_dir
run_server "$@"
