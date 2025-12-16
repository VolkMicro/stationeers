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
      libssl3 zlib1g \
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
