# ---------- builder: скачиваем Stationeers через SteamCMD ----------
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV STEAMCMD_DIR=/steamcmd
ENV INSTALL_DIR=/opt/stationeers

# SteamCMD linux32 => нужен i386 runtime
RUN dpkg --add-architecture i386 && \
    apt update && apt install -y \
      ca-certificates curl \
      libc6:i386 libstdc++6:i386 \
      libssl3 libssl3:i386 \
      zlib1g zlib1g:i386 \
    && rm -rf /var/lib/apt/lists/*

# SteamCMD (официальный tarball)
RUN mkdir -p ${STEAMCMD_DIR} && \
    cd ${STEAMCMD_DIR} && \
    curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz

RUN mkdir -p ${INSTALL_DIR}

# Скачиваем/обновляем dedicated server
RUN ${STEAMCMD_DIR}/steamcmd.sh \
    +force_install_dir ${INSTALL_DIR} \
    +login anonymous \
    +app_update 600760 validate \
    +quit


# ---------- runtime: только запуск сервера ----------
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV INSTALL_DIR=/opt/stationeers
ENV DATA_DIR=/data

# Минимальные зависимости рантайма
RUN apt update && apt install -y \
    ca-certificates \
    libssl3 zlib1g \
    libstdc++6 libgcc-s1 \
 && rm -rf /var/lib/apt/lists/*

# Непривилегированный пользователь (UID фиксируем для прав на volume)
RUN useradd --uid 1358 --user-group --create-home \
    --home ${DATA_DIR} --shell /sbin/nologin rocket

# Код сервера (immutable)
COPY --from=builder ${INSTALL_DIR} ${INSTALL_DIR}

# Данные (mutable) живут в /data и монтируются с хоста
RUN mkdir -p ${DATA_DIR} && chown -R 1358:1358 ${DATA_DIR}

USER rocket
WORKDIR ${DATA_DIR}

# Важно: абсолютный путь к бинарнику (исправляет твой "косяк")
ENTRYPOINT ["/opt/stationeers/rocketstation_DedicatedServer.x86_64"]

# Базовые флаги; параметры мира добавим через compose (STATIONEERS_ARGS)
CMD ["-nographics", "-batchmode"]


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
  && echo "${SUPERCRONIC_SHA256}  /tmp/supercronic" | sha256sum -c - \
  && install -m 0755 /tmp/supercronic /usr/local/bin/supercronic \
  && rm /tmp/supercronic

COPY scripts/backup-entrypoint.sh /usr/local/bin/backup-entrypoint.sh
RUN chmod 0755 /usr/local/bin/backup-entrypoint.sh

USER backup
WORKDIR ${BACKUP_HOME}

ENTRYPOINT ["/usr/local/bin/backup-entrypoint.sh"]
