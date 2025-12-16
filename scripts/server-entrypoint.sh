#!/bin/bash
set -euo pipefail

: "${INSTALL_DIR:=/opt/stationeers}"
: "${DATA_DIR:=/data}"
: "${SERVER_USER:=rocket}"
: "${WINEPREFIX:=/data/.wine}"
: "${WINEDEBUG:=-all}"

ensure_data_dir() {
  mkdir -p "${DATA_DIR}"
  chown -R "${SERVER_USER}:${SERVER_USER}" "${DATA_DIR}"
}

init_wine() {
  if [ ! -f "${WINEPREFIX}/system.reg" ]; then
    echo "==> Initializing Wine prefix at ${WINEPREFIX}"
    gosu "${SERVER_USER}" env WINEPREFIX="${WINEPREFIX}" WINEDEBUG="${WINEDEBUG}" wineboot --init
  fi
}

run_server() {
  cd "${INSTALL_DIR}"
  exec gosu "${SERVER_USER}" env \
    WINEPREFIX="${WINEPREFIX}" \
    WINEDEBUG="${WINEDEBUG}" \
    HOME="${DATA_DIR}" \
    wine64 "${INSTALL_DIR}/rocketstation_DedicatedServer.exe" "$@"
}

ensure_data_dir
init_wine
run_server "$@"
