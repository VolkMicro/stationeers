#!/bin/bash
set -euo pipefail

: "${INSTALL_DIR:=/opt/stationeers}"
: "${DATA_DIR:=/data}"
: "${SERVER_USER:=rocket}"
: "${SERVER_BINARY:=/opt/stationeers/rocketstation_DedicatedServer.x86_64}"
: "${SAVES_DIR:=/data/saves}"
: "${INSTALL_SAVES:=/opt/stationeers/saves}"

prepare_data_dir() {
  mkdir -p "${DATA_DIR}"
  chown -R "${SERVER_USER}:${SERVER_USER}" "${DATA_DIR}"
}

link_saves_dir() {
  mkdir -p "${SAVES_DIR}"
  chown -R "${SERVER_USER}:${SERVER_USER}" "${SAVES_DIR}"
  if [ ! -L "${INSTALL_SAVES}" ]; then
    # если уже есть папка, перенесём её содержимое и сделаем ссылку
    if [ -d "${INSTALL_SAVES}" ] && [ ! -L "${INSTALL_SAVES}" ]; then
      mv "${INSTALL_SAVES}"/* "${SAVES_DIR}" 2>/dev/null || true
      rmdir "${INSTALL_SAVES}" 2>/dev/null || true
    fi
    ln -s "${SAVES_DIR}" "${INSTALL_SAVES}"
  fi
}

run_server() {
  cd "${INSTALL_DIR}"
  exec gosu "${SERVER_USER}" env \
    HOME="${DATA_DIR}" \
    "${SERVER_BINARY}" "$@"
}

prepare_data_dir
link_saves_dir
run_server "$@"
