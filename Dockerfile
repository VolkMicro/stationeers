# ---------- builder: скачиваем Stationeers через SteamCMD (non-root) ----------
FROM cm2network/steamcmd:steam AS builder

USER steam
ENV STEAMCMD_DIR=/home/steam/steamcmd
ENV INSTALL_DIR=/home/steam/stationeers

ARG STATIONEERS_APP_ID=600760
ARG STATIONEERS_BRANCH=public        # public | beta | etc.
ARG STATIONEERS_BETAPASS=            # пароль для приватных веток (если нужен)
ARG STEAM_LOGIN=anonymous
ARG STEAM_PASSWORD=
ARG STEAM_GUARD_CODE=

RUN mkdir -p "${INSTALL_DIR}"

# Скачиваем/обновляем dedicated server
RUN set -eux; \
    BRANCH_ARGS=""; \
    if [ "${STATIONEERS_BRANCH}" != "public" ]; then \
      BRANCH_ARGS="-beta ${STATIONEERS_BRANCH}"; \
      if [ -n "${STATIONEERS_BETAPASS}" ]; then \
        BRANCH_ARGS="${BRANCH_ARGS} -betapassword ${STATIONEERS_BETAPASS}"; \
      fi; \
    fi; \
    LOGIN_ARGS="+login ${STEAM_LOGIN}"; \
    if [ "${STEAM_LOGIN}" != "anonymous" ]; then \
      LOGIN_ARGS="${LOGIN_ARGS} ${STEAM_PASSWORD}"; \
    fi; \
    GUARD_ARGS=""; \
    if [ -n "${STEAM_GUARD_CODE}" ]; then \
      GUARD_ARGS="+set_steam_guard_code ${STEAM_GUARD_CODE}"; \
    fi; \
    ${STEAMCMD_DIR}/steamcmd.sh \
      ${GUARD_ARGS} \
      +@ShutdownOnFailedCommand 1 \
      +force_install_dir "${INSTALL_DIR}" \
      ${LOGIN_ARGS} \
      +app_update "${STATIONEERS_APP_ID}" ${BRANCH_ARGS} validate \
      +quit


# ---------- backup runner: создаёт tar-архивы по cron ----------
FROM ubuntu:24.04 AS backup

ENV DEBIAN_FRONTEND=noninteractive
ENV BACKUP_HOME=/home/backup

ARG SUPERCRONIC_VERSION=0.2.1
# Если нужен контроль целостности, передайте правильный SHA256 через build-arg.
ARG SUPERCRONIC_SHA256=

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

RUN curl -fsSLo /tmp/supercronic \
      https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64 \
  && if [ -n "${SUPERCRONIC_SHA256}" ]; then \
       echo "${SUPERCRONIC_SHA256}  /tmp/supercronic" | sha256sum -c -; \
     else \
       echo "WARN: SUPERCRONIC_SHA256 not provided, skipping checksum verification"; \
     fi \
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
COPY --from=builder /home/steam/stationeers ${INSTALL_DIR}

# Скрипт запуска (подготовка /data + запуск под пользователем rocket)
COPY scripts/server-entrypoint.sh /usr/local/bin/server-entrypoint.sh
RUN chmod 0755 /usr/local/bin/server-entrypoint.sh

# Данные (mutable) живут в /data и монтируются с хоста
RUN mkdir -p ${DATA_DIR} && chown -R 1358:1358 ${DATA_DIR}

USER root
WORKDIR ${INSTALL_DIR}

ENTRYPOINT ["/usr/local/bin/server-entrypoint.sh"]

# Базовые флаги; параметры мира добавим через compose (STATIONEERS_ARGS)
CMD ["-nographics", "-batchmode"]
