# Stationeers dedicated server image.
# - builder: installs the game with SteamCMD
# - runtime: minimal non-root image to run the server
FROM cm2network/steamcmd:steam AS builder

USER steam
ENV STEAMCMD_DIR=/home/steam/steamcmd
ENV INSTALL_DIR=/home/steam/stationeers

ARG STATIONEERS_APP_ID=600760
ARG STATIONEERS_BRANCH=public        # public | beta | etc.
ARG STATIONEERS_BETAPASS=
ARG STEAM_LOGIN=anonymous            # steamcmd login, anonymous by default
ARG STEAM_PASSWORD=                  # required if STEAM_LOGIN is not anonymous
ARG STEAM_GUARD_CODE=                # optional
ARG STEAMCMD_FORCE_PLATFORM=         # optional, e.g. windows (only if SteamCMD needs it)

RUN mkdir -p "${INSTALL_DIR}"

RUN set -eux; \
    FORCE_PLATFORM_ARGS=""; \
    if [ -n "${STEAMCMD_FORCE_PLATFORM}" ]; then \
      FORCE_PLATFORM_ARGS="+@sSteamCmdForcePlatformType ${STEAMCMD_FORCE_PLATFORM}"; \
    fi; \
    BRANCH_ARGS=""; \
    # always pin a branch explicitly; default is public
    BRANCH_ARGS="-beta ${STATIONEERS_BRANCH}"; \
    if [ -n "${STATIONEERS_BETAPASS}" ]; then \
      BRANCH_ARGS="${BRANCH_ARGS} -betapassword ${STATIONEERS_BETAPASS}"; \
    fi; \
    LOGIN_ARGS="+login ${STEAM_LOGIN}"; \
    if [ "${STEAM_LOGIN}" != "anonymous" ]; then \
      LOGIN_ARGS="${LOGIN_ARGS} ${STEAM_PASSWORD}"; \
      if [ -n "${STEAM_GUARD_CODE}" ]; then \
        LOGIN_ARGS="${LOGIN_ARGS} ${STEAM_GUARD_CODE}"; \
      fi; \
    fi; \
    GUARD_ARGS=""; \
    if [ -n "${STEAM_GUARD_CODE}" ] && [ "${STEAM_LOGIN}" = "anonymous" ]; then \
      GUARD_ARGS="+set_steam_guard_code ${STEAM_GUARD_CODE}"; \
    fi; \
    for i in 1 2 3; do \
      ${STEAMCMD_DIR}/steamcmd.sh \
        ${FORCE_PLATFORM_ARGS} \
        ${GUARD_ARGS} \
        +@ShutdownOnFailedCommand 1 \
        +force_install_dir "${INSTALL_DIR}" \
        ${LOGIN_ARGS} \
        +app_update "${STATIONEERS_APP_ID}" ${BRANCH_ARGS} validate \
        +quit && break; \
      echo "steamcmd attempt ${i} failed, retrying in 5s..."; \
      sleep 5; \
    done


FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV INSTALL_DIR=/opt/stationeers
ENV DATA_DIR=/data

# Unity headless dependencies + gosu (drops privileges to the runtime user)
RUN apt update && apt install -y \
        ca-certificates \
        libcurl4 \
        libkrb5-3 \
        libgssapi-krb5-2 \
        libssl3 zlib1g \
        libstdc++6 libgcc-s1 \
        gosu \
    && rm -rf /var/lib/apt/lists/*

# Non-root runtime user (UID/GID 1358)
RUN useradd --uid 1358 --user-group --create-home \
    --home ${DATA_DIR} --shell /usr/sbin/nologin rocket

# Game install (immutable)
COPY --from=builder /home/steam/stationeers ${INSTALL_DIR}
RUN chown -R 1358:1358 ${INSTALL_DIR}

# Entrypoint script
COPY scripts/server-entrypoint.sh /usr/local/bin/server-entrypoint.sh
RUN chmod 0755 /usr/local/bin/server-entrypoint.sh

# Mutable data dir
RUN mkdir -p ${DATA_DIR} && chown -R 1358:1358 ${DATA_DIR}

USER root
WORKDIR ${INSTALL_DIR}

ENTRYPOINT ["/usr/local/bin/server-entrypoint.sh"]

CMD ["-nographics", "-batchmode"]
