# Stationeers Dedicated Server (Docker, Ubuntu 24.04)

Архитектура:
- `/opt/stationeers` внутри образа: нативный Linux-билд сервера (immutable)
- `./data` на хосте → `/data` в контейнере: сейвы, логи, `settings.xml`, бэкапы (mutable)
- `./backups`: папка для архивов (опционально, сервис выключен по умолчанию)

## Требования
- Docker + Docker Compose plugin
- Хостовая ОС: Ubuntu 24.04 / Debian 12 (glibc ≥ 2.38)
- Вы владеете Stationeers в Steam: для скачивания через SteamCMD нужен аккаунт с лицензией (анонимный доступ больше не выдаёт конфигурацию приложения `600760`)

## Быстрый старт
```bash
cp .env.example .env
./scripts/fix-perms.sh        # на Linux удобно сразу выставить права

# Сборка: обязательно передайте учётку Steam
docker compose build \
  --no-cache \
  --build-arg STEAM_LOGIN="my_steam_login" \
  --build-arg STEAM_PASSWORD="my_steam_password"

docker compose up -d
docker logs -f stationeers
```

Если на аккаунте включён Steam Guard, передайте одноразовый код:

```
--build-arg STEAM_GUARD_CODE=12345
```

Креды попадают только в слои stage `builder`; финальный `runtime` не содержит ни SteamCMD, ни учётных данных.

## Что внутри

- Stage `builder` устанавливает SteamCMD (i386 runtime) и, будучи авторизованным в Steam, качает приложение `600760` (`rocketstation_DedicatedServer.x86_64`).
- Stage `runtime` содержит только нужные системные библиотеки + `gosu`; запуском руководит `scripts/server-entrypoint.sh`, который:
  - гарантирует существование `/data` и владельца `rocket:rocket`;
  - стартует бинарник от пользователя `rocket`, подставляя аргументы из `docker-compose.yml`.

Сервис бэкапов пока закомментирован в `docker-compose.yml`. Когда сервер стабильно запускается — раскомментируйте блок `backup` и задайте `BACKUP_CRON`/`BACKUP_KEEP_DAYS` в `.env`.

Dockerfile по умолчанию собирает runtime-образ; stage `backup` оставлен «на будущее» и сейчас не участвует в `docker compose build`.
