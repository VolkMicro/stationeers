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
