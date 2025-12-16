# Stationeers Dedicated Server (Docker, Ubuntu 24.04)

Продакшн-ориентированный стек:
- immutable-образ с бинарём сервера (скачивается только на этапе build через SteamCMD)
- runtime без root (UID/GID 1358), данные только в bind-mount `./data`
- отдельный контейнер для бэкапов (tar + ротация)
- настройки через `.env`

## Архитектура
- `Dockerfile` — multi-stage:
  - `builder` (cm2network/steamcmd:steam) скачивает `600760` в `/home/steam/stationeers` под пользователем steam; поддерживает ветки `public/beta` и Steam Guard.
  - `runtime` (ubuntu:24.04) содержит только зависимости Unity headless + `gosu`, копирует билд в `/opt/stationeers`, стартует под пользователем `rocket` (UID 1358).
  - `backup` (ubuntu:24.04 + supercronic) создаёт tar.gz из `/data` в `/backups`, чистит старые.
- `docker-compose.yml` — сервисы `stationeers` и `backup`, оба монтируют `./data`, бэкапы пишутся в `./backups`.
- Сейвы/логи/настройки — **только** в `./data` (volume). Существующий сейв «Луна» подхватывается, если `STATIONEERS_ARGS` указывает на то же имя.

## Запуск с нуля
```bash
cp .env.example .env
# при необходимости поправьте STATIONEERS_ARGS под ваш сейв/мир

# сборка (анонимный доступ работает; при необходимости можно передать логин/пароль/guard-код)
docker compose build --no-cache --build-arg STEAM_LOGIN=anonymous

docker compose up -d
docker logs -f stationeers
```
Порты: `27016/udp` (game), `27015/udp` (query) пробросаны из `.env`.

## Обновление сервера
```bash
./scripts/update.sh
```
Скрипт пересобирает образ (скачивает новый билд через SteamCMD в builder-стейдже) и перезапускает compose. Данные в `./data` не трогаются.

## Бэкапы
- Фоновый контейнер `backup` по `BACKUP_CRON` кладёт архивы в `./backups/stationeers_<timestamp>.tar.gz` и удаляет старше `BACKUP_KEEP_DAYS`.
- Разовый бэкап:
  ```bash
  ./scripts/backup.sh
  ```
- Восстановление: остановите сервер, распакуйте нужный архив в `./data`, запустите снова.

## Перенос сейвов
1. Остановите контейнер: `docker compose down`.
2. Скопируйте вашу папку `saves/<имя_мира>` в `./data/saves/...`.
3. Убедитесь, что `STATIONEERS_ARGS` указывает на тот же `stationname/worldid`.
4. Запустите `docker compose up -d`.

## Почему так
- SteamCMD только в builder: нет сетевых скачиваний в runtime, минимальный образ.
- Non-root runtime + фиксированный UID/GID 1358: корректные права на тома и безопасность.
- Данные строго в volume `./data`: обновления образа не трогают сейвы.
- Бэкапы в отдельном контейнере: можно включить/отключить независимо, ротация по дням.
- Фиксированные базовые образы (`cm2network/steamcmd:steam`, `ubuntu:24.04`): воспроизводимость.

## Известные грабли / решения
- Если SteamCMD снова начнёт отказывать анониму: соберите образ с `--build-arg STEAM_LOGIN/STEAM_PASSWORD/STEAM_GUARD_CODE`, либо скачайте билд вне Docker и положите в `./data` (но предпочтительнее логин).
- UID/GID на хосте должны позволять запись в `./data`/`./backups`. При необходимости выполните `chown -R 1358:1358 data backups`.
