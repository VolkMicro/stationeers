# Stationeers Dedicated Server (Docker, Ubuntu 24.04)

Продакшн-ориентированное развертывание: immutable-образ, non-root runtime, данные только в bind-mount, отдельный контейнер бэкапов.

## Архитектура
- **Dockerfile (multi-stage)**
  - **builder**: `cm2network/steamcmd:steam`, скачивает приложение `600760` в `/home/steam/stationeers` под пользователем steam. Поддерживает ветки `public`/`beta`, Steam Guard, приватные бета-пароли.
  - **runtime**: `ubuntu:24.04`, только Unity-зависимости + `gosu`, пользователь `rocket` (UID/GID 1358). Копирует билд в `/opt/stationeers`, жёстко линкует `/opt/stationeers/saves -> /data/saves`.
  - **backup**: `ubuntu:24.04` + `supercronic`, пользователь `backup` (UID/GID 1358). Делает tar.gz из `/data` в `/backups`, чистит старше `BACKUP_KEEP_DAYS`.
- **docker-compose.yml**: сервисы `stationeers` и `backup`, общие тома `./data` и `./backups`, порты берутся из `.env`.
- **Данные**: сейвы, логи, конфиги — строго в `./data` (bind-mount). Сейв «Lunar» или другой подхватывается, если имя станции в `STATIONEERS_ARGS` совпадает с папкой `./data/saves/<StationName>`.

## Быстрый старт
```bash
cp .env.example .env
# при необходимости подправьте STATIONEERS_ARGS (stationname/worldid, порт, путь лога /data/server.log)

mkdir -p data backups
sudo chown -R 1358:1358 data backups   # или chown без sudo

docker compose build --no-cache --build-arg STEAM_LOGIN=anonymous
docker compose up -d
docker logs -f stationeers
```
Порты по умолчанию: `27016/udp` (game) и `27015/udp` (query), задаются в `.env`.

## Импорт существующего сейва
1. `docker compose down`
2. Скопируйте сейв в `./data/saves/<StationName>` (например, `./data/saves/Lunar`).
3. В `.env` в `STATIONEERS_ARGS` первый параметр после `-file start` должен совпадать с `<StationName>`.
4. `sudo chown -R 1358:1358 data/saves`
5. `docker compose up -d` и проверьте `tail -n 50 data/server.log` — не должно быть "Created new save".

## Обновление сервера
```bash
./scripts/update.sh    # docker compose build --pull && up -d
```
SteamCMD работает только в builder-стейдже; `./data` не трогается.

## Бэкапы
- Фоновый контейнер `backup` по `BACKUP_CRON` кладёт архивы в `./backups/stationeers_<timestamp>.tar.gz`, удаляет старше `BACKUP_KEEP_DAYS`.
- Разовый бэкап: `./scripts/backup.sh`
- Восстановление: `docker compose down`, распаковать архив в `./data`, `docker compose up -d`.

## Важные переменные `.env`
- `STATIONEERS_GAME_PORT`, `STATIONEERS_QUERY_PORT` — внешние UDP-порты.
- `STATIONEERS_ARGS` — CLI сервера (рекомендуется `-logFile "/data/server.log"` и `LocalIpAddress 0.0.0.0`; stationname совпадает с папкой сейва).
- `STATIONEERS_BRANCH`, `STATIONEERS_BETAPASS` — ветка/пароль beta (по умолчанию public).
- `BACKUP_CRON`, `BACKUP_KEEP_DAYS` — расписание и ротация бэкапов.

## Почему так
- SteamCMD только на этапе сборки: минимальный runtime, без сетевых скачиваний.
- Non-root runtime с фиксированным UID/GID 1358: корректные права на тома и безопасность.
- Жёсткий symlink `/opt/stationeers/saves -> /data/saves`: сейвы всегда в bind-mount, обновление образа не трогает данные.
- Отдельный контейнер бэкапов: независимое расписание и ротация.
- Фиксированные базовые образы (`cm2network/steamcmd:steam`, `ubuntu:24.04`): воспроизводимая сборка.

## Известные грабли
- Если SteamCMD откажет анониму — соберите с `--build-arg STEAM_LOGIN/STEAM_PASSWORD/STEAM_GUARD_CODE`.
- Если сервер создаёт новый мир — проверьте совпадение stationname с папкой в `./data/saves` и права (`chown -R 1358:1358 data`).
- Предупреждение о `version` в compose можно игнорировать или удалить строку `version: "3.8"` в `docker-compose.yml`.
