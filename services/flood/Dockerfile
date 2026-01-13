# syntax=docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6

# renovate: datasource=github-releases depName=jesec/flood
ARG FLOOD_VERSION='4.10.0'

# === Stage 0 - Disambiguation =================================================
FROM gcr.io/distroless/nodejs22-debian12:debug@sha256:573675bb74f91be915013957c2a35ffe6aae2bc250622e373c01c51ba818e298 AS disambiguation

# Setup busybox symlinks
RUN [ "/busybox/ln", "-s", "/busybox/sh", "/bin/sh" ]
RUN [ "/busybox/ln", "-s", "/busybox/env", "/usr/bin/env" ]

RUN find / -type f -name '*.so*' | sort | uniq > /libs.txt

# === Stage 1 - Install Flood ==================================================
FROM docker.io/library/node:24.12.0-bookworm@sha256:929c026d5a4e4a59685b3c1dbc1a8c3eb090aa95373d3a4fd668daa2493c8331 AS install

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
FROM docker.io/library/busybox:stable-musl@sha256:c29b078aeeb7cdc487cf52dc87a69dac71499937f498b35cb606c7943bc412c9 AS busybox

# === Stage 3 - Runtime ========================================================
FROM gcr.io/distroless/nodejs22-debian12@sha256:51c3cf288add1c7b3d28c3bd1475379fd73d3a3c5a3c8ff88830dde3e49758c4

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
