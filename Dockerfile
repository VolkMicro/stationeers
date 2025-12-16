# ---------- builder: скачиваем Stationeers через SteamCMD ----------
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV STEAMCMD_DIR=/steamcmd
ENV INSTALL_DIR=/opt/stationeers
ARG STATIONEERS_APP_ID=600760
ARG STEAM_LOGIN=anonymous
ARG STEAM_PASSWORD=
ARG STEAM_GUARD_CODE=

# SteamCMD linux32 => нужен полноценный i386 runtime
RUN dpkg --add-architecture i386 && \
    apt update && apt install -y \
      ca-certificates curl \
      libc6:i386 libstdc++6:i386 \
      libssl3 libssl3:i386 \
      lib32gcc-s1 \
      zlib1g zlib1g:i386 \
    && rm -rf /var/lib/apt/lists/*

# SteamCMD (официальный tarball)
RUN mkdir -p ${STEAMCMD_DIR} && \
    cd ${STEAMCMD_DIR} && \
    curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz

RUN mkdir -p ${INSTALL_DIR}

# Скачиваем/обновляем dedicated server
# Дополнительные флаги:
# - @sSteamCmdForcePlatformType linux — гарантируем linux-билд
# - @ShutdownOnFailedCommand 1      — немедленно прерывать выполнение при ошибке
RUN set -eux; \
    if [ -z "${STEAM_LOGIN}" ]; then \
      echo "ERROR: STEAM_LOGIN build arg is required" >&2; exit 1; \
    fi; \
    if [ "${STEAM_LOGIN}" != "anonymous" ] && [ -z "${STEAM_PASSWORD}" ]; then \
      echo "ERROR: STEAM_PASSWORD build arg is required when STEAM_LOGIN is not anonymous" >&2; exit 1; \
    fi; \
    GUARD_ARGS=""; \
    if [ -n "${STEAM_GUARD_CODE}" ]; then \
      GUARD_ARGS="+set_steam_guard_code ${STEAM_GUARD_CODE}"; \
    fi; \
    LOGIN_ARGS="+login ${STEAM_LOGIN}"; \
    if [ "${STEAM_LOGIN}" = "anonymous" ]; then \
      LOGIN_ARGS="${LOGIN_ARGS}"; \
    else \
      LOGIN_ARGS="${LOGIN_ARGS} ${STEAM_PASSWORD}"; \
    fi; \
    ${STEAMCMD_DIR}/steamcmd.sh \
        ${GUARD_ARGS} \
        +@sSteamCmdForcePlatformType linux \
        +@ShutdownOnFailedCommand 1 \
        +force_install_dir ${INSTALL_DIR} \
        ${LOGIN_ARGS} \
        +app_update ${STATIONEERS_APP_ID} validate \
        +quit


# ---------- backup runner: без root, без скачиваний на старте ----------
FROM ubuntu:24.04 AS backup

ENV DEBIAN_FRONTEND=noninteractive
ENV BACKUP_HOME=/home/backup

ARG SUPERCRONIC_VERSION=0.2.1
ARG SUPERCRONIC_SHA256=191b320b3cb44bfae1654aefb2c6c2d4c195c46bd0a65bb3c87d2e4093e71279

RUN apt update && apt install -y \
    ca-certificates \
    coreutils \
    curl \
    findutils \
    gzip \
    tar \
  && rm -rf /var/lib/apt/lists/*

RUN if ! getent group backup >/dev/null; then \
      groupadd --gid 1358 backup; \
    else \
      groupmod --gid 1358 backup; \
    fi \
 && if ! id -u backup >/dev/null 2>&1; then \
      useradd --uid 1358 --gid backup --create-home --home ${BACKUP_HOME} --shell /usr/sbin/nologin backup; \
    else \
      usermod --uid 1358 --gid backup --home ${BACKUP_HOME} --shell /usr/sbin/nologin backup; \
      mkdir -p ${BACKUP_HOME}; \
    fi

# supercronic: cron совместимый планировщик без демона cron
RUN curl -fsSLo /tmp/supercronic \
      https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64 \
#  && echo "${SUPERCRONIC_SHA256}  /tmp/supercronic" | sha256sum -c - \
  && install -m 0755 /tmp/supercronic /usr/local/bin/supercronic \
  && rm /tmp/supercronic

COPY scripts/backup-entrypoint.sh /usr/local/bin/backup-entrypoint.sh
RUN chmod 0755 /usr/local/bin/backup-entrypoint.sh

USER backup
WORKDIR ${BACKUP_HOME}

ENTRYPOINT ["/usr/local/bin/backup-entrypoint.sh"]


# ---------- runtime: только запуск сервера (финальный образ по умолчанию) ----------
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV INSTALL_DIR=/opt/stationeers
ENV DATA_DIR=/data

# Минимальные зависимости Unity headless + gosu
RUN apt update && apt install -y \
        ca-certificates \
        libcurl4 \
        libkrb5-3 \
        libgssapi-krb5-2 \
        libssl3 zlib1g \
        libstdc++6 libgcc-s1 \
        gosu \
    && rm -rf /var/lib/apt/lists/*

# Непривилегированный пользователь (UID фиксируем для прав на volume)
RUN useradd --uid 1358 --user-group --create-home \
    --home ${DATA_DIR} --shell /usr/sbin/nologin rocket

# Код сервера (immutable)
COPY --from=builder ${INSTALL_DIR} ${INSTALL_DIR}

# Скрипт запуска (подготовка /data + запуск под пользователем rocket)
COPY scripts/server-entrypoint.sh /usr/local/bin/server-entrypoint.sh
RUN chmod 0755 /usr/local/bin/server-entrypoint.sh

# Данные (mutable) живут в /data и монтируются с хоста
RUN mkdir -p ${DATA_DIR} && chown -R 1358:1358 ${DATA_DIR}

USER root

# Важный момент: исполняемый файл ожидает соседнюю папку `rocketstation_Data`.
# Если рабочая директория указывает на /data, Unity не найдёт ресурсы (StreamingAssets),
# что приводит к ошибкам шейдеров и NullReference в WorldManager при загрузке.
# Поэтому запускаем сервер из каталога установки, а сохранения остаются в $HOME (/data).
WORKDIR ${INSTALL_DIR}

ENTRYPOINT ["/usr/local/bin/server-entrypoint.sh"]

# Базовые флаги; параметры мира добавим через compose (STATIONEERS_ARGS)
CMD ["-nographics", "-batchmode"]
