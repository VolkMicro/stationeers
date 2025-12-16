# Stationeers Dedicated Server (Docker, Ubuntu 24.04)

Архитектура:
- /opt/stationeers внутри образа: код сервера (immutable)
- ./data на хосте монтируется в /data: сейвы/логи/конфиги (mutable)
- ./backups: архивы бэкапов

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

Сервис бэкапов собирается из этого же Dockerfile (stage `backup`):
- не запускается от root (UID/GID 1358)
- не тянет apt при старте: используем встроенный планировщик supercronic
- cron-правила задаются переменной `BACKUP_CRON` (пример в `.env.example`)

Важно: переменные `BACKUP_CRON` и `BACKUP_KEEP_DAYS` обязательны. Если их не задать в `.env`, контейнеры будут падать с ошибкой `BACKUP_CRON is required`.

Dockerfile по умолчанию собирает серверный образ (stage `runtime`), а для бэкапов используется отдельный target `backup`, указанный в `docker-compose.yml`.
