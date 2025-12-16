#!/bin/bash
set -euo pipefail

: "${BACKUP_CRON:?BACKUP_CRON is required}" 
: "${BACKUP_KEEP_DAYS:?BACKUP_KEEP_DAYS is required}"

BACKUP_ROOT="${BACKUP_ROOT:-/home/backup}"

# Подготавливаем вспомогательный скрипт бэкапа (один архив на запуск)
cat >"${BACKUP_ROOT}/backup.sh" <<'BACKUP'
#!/bin/bash
set -euo pipefail
TS=$(date +%F_%H-%M-%S)
mkdir -p /backups

tar -czf "/backups/stationeers_${TS}.tar.gz" -C /data .
find /backups -type f -name "stationeers_*.tar.gz" -mtime +${BACKUP_KEEP_DAYS} -delete
BACKUP
chmod 0755 "${BACKUP_ROOT}/backup.sh"

# Планировщик supercronic (не требует root, не тянет apt во время запуска)
cat >"${BACKUP_ROOT}/supercronic.cron" <<CRON
${BACKUP_CRON} ${BACKUP_ROOT}/backup.sh >>/backups/backup.log 2>&1
CRON

exec supercronic "${BACKUP_ROOT}/supercronic.cron"
