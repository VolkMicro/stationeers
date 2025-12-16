# Stationeers Dedicated Server (Docker, Ubuntu 24.04)

Архитектура:
- /opt/stationeers внутри образа: код сервера (immutable)
- ./data на хосте монтируется в /data: сейвы/логи/конфиги (mutable)
- ./backups: архивы бэкапов (временно не используются)

## Требования
- Docker + Docker Compose plugin
- Хост: Ubuntu 24.04 (glibc 2.38)

## Быстрый старт
```bash
cp .env.example .env
./scripts/fix-perms.sh
docker compose build --no-cache
docker compose up -d
docker logs -f stationeers
```

Сервис бэкапов временно отключён (закомментирован в `docker-compose.yml`), чтобы сначала развернуть и проверить сам сервер. Его можно
вернуть позже, раскомментировав блок `backup` и добавив переменные `BACKUP_CRON` и `BACKUP_KEEP_DAYS` в `.env`.

Dockerfile по умолчанию собирает серверный образ (stage `runtime`); stage `backup` оставлен для будущего, но сейчас не используется.
