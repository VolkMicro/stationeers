#!/bin/bash
set -euo pipefail

: "${BACKUP_CRON:?BACKUP_CRON is required (e.g. */30 * * * *)}"
: "${BACKUP_KEEP_DAYS:?BACKUP_KEEP_DAYS is required (e.g. 14)}"
: "${BACKUP_ROOT:=/home/backup}"
: "${DATA_DIR:=/data}"
: "${BACKUP_DIR:=/backups}"

backup_script="${BACKUP_ROOT}/backup.sh"
cron_file="${BACKUP_ROOT}/supercronic.cron"

cat >"${backup_script}" <<'EOF'
#!/bin/bash
set -euo pipefail
TS=$(date +%F_%H-%M-%S)
mkdir -p "${BACKUP_DIR}"
tar -czf "${BACKUP_DIR}/stationeers_${TS}.tar.gz" -C "${DATA_DIR}" .
find "${BACKUP_DIR}" -type f -name "stationeers_*.tar.gz" -mtime +${BACKUP_KEEP_DAYS} -delete
EOF
chmod 0755 "${backup_script}"

cat >"${cron_file}" <<EOF
${BACKUP_CRON} ${backup_script} >>${BACKUP_DIR}/backup.log 2>&1
EOF

if [ "${RUN_ONCE:-0}" = "1" ]; then
  exec "${backup_script}"
fi

exec supercronic "${cron_file}"
