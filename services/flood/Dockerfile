# syntax=docker/dockerfile:1@sha256:4c68376a702446fc3c79af22de146a148bc3367e73c25a5803d453b6b3f722fb

# renovate: datasource=github-releases depName=jesec/flood
ARG FLOOD_VERSION='4.9.3'

# === Stage 0 - Disambiguation =================================================
FROM gcr.io/distroless/nodejs22-debian12:debug@sha256:14f063fea03b3388280a1aec9cc500b397f2fb378a7f193c0701227714b82a24 AS disambiguation

# Setup busybox symlinks
RUN [ "/busybox/ln", "-s", "/busybox/sh", "/bin/sh" ]
RUN [ "/busybox/ln", "-s", "/busybox/env", "/usr/bin/env" ]

RUN find / -type f -name '*.so*' | sort | uniq > /libs.txt

# === Stage 1 - Install Flood ==================================================
FROM docker.io/library/node:22.14.0-bookworm@sha256:e5ddf893cc6aeab0e5126e4edae35aa43893e2836d1d246140167ccc2616f5d7 AS install

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
FROM docker.io/library/busybox:stable-musl@sha256:52931c5795db81b02f89211b300630477f851870b5504d6883c7c38f99f4e692 AS busybox

# === Stage 3 - Runtime ========================================================
FROM gcr.io/distroless/nodejs22-debian12@sha256:b0df7917d86c254e76d0855775679d9ee4ec7c307503259d92f431b618393a4d

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
