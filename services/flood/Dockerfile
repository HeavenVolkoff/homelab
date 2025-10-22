# syntax=docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6

# renovate: datasource=github-releases depName=jesec/flood
ARG FLOOD_VERSION='4.10.0'

# === Stage 0 - Disambiguation =================================================
FROM gcr.io/distroless/nodejs22-debian12:debug@sha256:45139f50f2be41dcb50215aa58d184e1cc7bd41e1e2ece14be485f99fdf88c18 AS disambiguation

# Setup busybox symlinks
RUN [ "/busybox/ln", "-s", "/busybox/sh", "/bin/sh" ]
RUN [ "/busybox/ln", "-s", "/busybox/env", "/usr/bin/env" ]

RUN find / -type f -name '*.so*' | sort | uniq > /libs.txt

# === Stage 1 - Install Flood ==================================================
FROM docker.io/library/node:22.20.0-bookworm@sha256:915acd9e9b885ead0c620e27e37c81b74c226e0e1c8177f37a60217b6eabb0d7 AS install

# Don't allow APT to make question
ARG DEBIAN_FRONTEND=noninteractive

# http://stackoverflow.com/questions/48162574/ddg#49462622
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

# Configure apt
COPY --from=utilities apt.conf /etc/apt/apt.conf.d/99docker-apt-config
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN rm -f /etc/apt/apt.conf.d/docker-clean

# Install dependencies
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
    set -xeu \
    && \
    apt-get update \
    && \
    apt-get full-upgrade \
    && \
    apt-get install mediainfo coreutils

COPY --from=disambiguation /libs.txt ./

RUN set -eux; \
    for _bin in '/usr/bin/mediainfo' '/usr/bin/df'; do \
        for _so in $( \
            ldd "$_bin" | awk '{print $3}' | sort | uniq | comm -23 - ./libs.txt \
        ); do \
            if [ -f "$_so" ]; then \
                install -D -t "/srv$(dirname "$_so")" $_so; \
            fi \
        ; done \
        && \
        install -D -t /srv/usr/bin/ "$_bin" \
    ; done

ARG FLOOD_VERSION

# Install flood
RUN --mount=type=cache,sharing=locked,target=/root/.npm \
    npm i -g flood@${FLOOD_VERSION}

# === Stage 2 - Busybox ========================================================
FROM docker.io/library/busybox:stable-musl@sha256:2f9af5cf39068ec3a9e124feceaa11910c511e23a1670dcfdff0bc16793545fb AS busybox

# === Stage 3 - Runtime ========================================================
FROM gcr.io/distroless/nodejs22-debian12@sha256:6d3a88ffd7d07ae86d1ee973b8f889c4e5f8f1235bac2b1099435385c04a8bef

ARG FLOOD_VERSION

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
	NODE_ENV=production \
    FLOOD_DATA_DIR=/usr/share/flood

COPY --from=busybox /bin/busybox /bin/busybox

RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ln -s /bin/env /usr/bin/env

COPY                  entrypoint.sh    /usr/local/bin/
COPY --from=utilities getent.sh        /usr/local/bin/getent
COPY --from=utilities entrypoint.shlib /usr/local/bin/

COPY --from=install   /usr/local/lib/node_modules/flood /usr/local/lib/node_modules/flood
COPY --from=install   /srv/                             /

RUN ln -s /nodejs/bin/node /usr/local/bin/node \
    && ln -s ../lib/node_modules/flood/dist/index.js /usr/local/bin/flood

EXPOSE 3000/tcp

VOLUME ["$FLOOD_DATA_DIR"]

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

LABEL org.opencontainers.image.title="Flood" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.description="A modern web UI for various torrent clients with a Node.js backend and React frontend"
