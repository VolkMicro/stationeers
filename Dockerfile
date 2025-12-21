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
ARG STEAM_LOGIN                      # required: Steam account (or set to anonymous explicitly)
ARG STEAM_PASSWORD                   # required if STEAM_LOGIN is not anonymous
ARG STEAM_GUARD_CODE=                # optional

RUN mkdir -p "${INSTALL_DIR}"

RUN set -eux; \
    if [ -z "${STEAM_LOGIN}" ]; then \
      echo "ERROR: STEAM_LOGIN is required (set to your Steam account or 'anonymous')."; \
      exit 1; \
    fi; \
    if [ "${STEAM_LOGIN}" != "anonymous" ] && [ -z "${STEAM_PASSWORD}" ]; then \
      echo "ERROR: STEAM_PASSWORD is required when STEAM_LOGIN is not anonymous."; \
      exit 1; \
    fi; \
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
      if [ -n "${STEAM_GUARD_CODE}" ]; then \
        LOGIN_ARGS="${LOGIN_ARGS} ${STEAM_GUARD_CODE}"; \
      fi; \
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
