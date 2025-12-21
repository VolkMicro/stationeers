# Stationeers Dedicated Server (Docker, Ubuntu 24.04)

Container setup for a Stationeers dedicated server. The build is split into a SteamCMD builder stage and a small runtime image that runs as a non-root user and keeps all mutable data in `./data`.

## What's inside
- `Dockerfile`: installs Stationeers with SteamCMD (builder) and ships a lean runtime with `gosu` (UID/GID 1358).
- `docker-compose.yml`: single `stationeers` service binding `./data -> /data`.
- `scripts/server-entrypoint.sh`: prepares `/data`, links `/opt/stationeers/saves` to `/data/saves`, then execs the server.
- `.env.example`: defaults to generating a fresh Mars world named `MarsBase` and logging to `/data/server.log`; includes Steam login envs passed at build time.
- No backup sidecar; rely on the game's autosaves or your own external snapshots.
- Optional Steam login build args are wired through compose (`STEAM_LOGIN/STEAM_PASSWORD/STEAM_GUARD_CODE`) in case anonymous download fails with `Missing configuration`.

## Quick start (fresh Mars world)
```bash
cp .env.example .env
# Edit .env and set STEAM_LOGIN/STEAM_PASSWORD (account that owns Stationeers; 2FA code optional)
mkdir -p data
# Optional: chown -R 1358:1358 data   # matches the runtime UID/GID

docker compose build --no-cache      # uses your Steam credentials to download
docker compose up -d
docker logs -f stationeers
```
The default `STATIONEERS_ARGS` run `-file start MarsBase Mars ...`, so the server creates an empty Mars map on first launch. Saves live in `./data/saves/MarsBase`, and autosaves keep progress.

## Changing the world
- To regenerate from scratch, stop the container and delete `./data/saves/MarsBase` (or set `STATIONEERS_ARGS` to a new world name/map), then start again.
- Adjust ports or other settings in `.env`.
- If SteamCMD errors with `Missing configuration`, set `STEAM_LOGIN`, `STEAM_PASSWORD`, and (if needed) `STEAM_GUARD_CODE` in `.env` (account must own Stationeers), then rebuild so the builder logs in with your account.

## Updating the install
```bash
./scripts/update.sh
```
