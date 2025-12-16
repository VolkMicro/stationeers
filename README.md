# Stationeers Dedicated Server (Docker, Ubuntu 24.04)

Архитектура:
- /opt/stationeers внутри образа: Windows-билд сервера (immutable)
- ./data на хосте → /data в контейнере: сейвы, логи, Wine-префикс (mutable)
- ./backups: архивы бэкапов (временно отключено)

## Требования
- Docker + Docker Compose plugin
- 64-bit Linux с поддержкой Wine (проверено на Ubuntu 24.04)

## Быстрый старт
```bash
cp .env.example .env
./scripts/fix-perms.sh   # опционально, но полезно на Linux-хостах
docker compose build --no-cache
docker compose up -d
docker logs -f stationeers
```

## Что внутри

- Stage `builder` скачивает Windows-версию приложения `600760` через SteamCMD с флагом `@sSteamCmdForcePlatformType windows`.
- Stage `runtime` ставит Wine (`wine64`, `wine32`, `winbind`, `cabextract`), инициализирует префикс в `/data/.wine` и запускает `rocketstation_DedicatedServer.exe` через `wine64`.
- Скрипт `server-entrypoint.sh` сам следит за правами на `/data`, первичной инициализацией Wine и передачей аргументов из `docker-compose.yml`.

Сервис бэкапов пока закомментирован в `docker-compose.yml`, чтобы сфокусироваться на запуске сервера. Верните его позже, раскомментировав блок `backup` и убедившись, что переменные `BACKUP_CRON` и `BACKUP_KEEP_DAYS` прописаны в `.env`.

Dockerfile по умолчанию собирает серверный образ (stage `runtime`); stage `backup` оставлен для будущего, но сейчас не используется.
