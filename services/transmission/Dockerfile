# syntax=docker/dockerfile:1

# === Stage 0 - Install Transmission ===========================================
FROM docker.io/library/alpine:edge AS install

ADD https://git.alpinelinux.org/aports/plain/community/transmission/APKBUILD APKBUILD

RUN apk upgrade --no-cache
RUN apk add --no-cache transmission-daemon binutils
RUN set -eu; \
    for _bin in "$(realpath "$(command -v transmission-daemon)")"; do \
        for _so in $( \
            ldd "$_bin" | awk '{print $3}' | sort | uniq \
        ); do \
            if [ -f "$_so" ]; then \
                install -Ds -t "/srv$(dirname "$_so")" $_so; \
            fi \
        ; done \
        && \
        install -Ds -t /srv/usr/bin/ "$_bin" \
    ; done

# === Stage 1 - Busybox ========================================================
FROM busybox:stable-musl AS busybox

# === Stage 2 - Runtime ========================================================
FROM gcr.io/distroless/static-debian12

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
    TRANSMISSION_RPC_PORT=9091 \
    TRANSMISSION_PEER_PORT=51413 \
    TRANSMISSION_CONF_DIR=/etc/transmission \
    TRANSMISSION_WATCH_DIR=/usr/share/transmission/watch \
    TRANSMISSION_DOWNLOAD_DIR=/download

# Tool to parse /etc/passwd
ADD --chmod=755 --checksum=sha256:a99beabea22571cfad4f77422e5d3ed922d9490232d94cb87cf32956766bc42a \
    https://github.com/kraj/uClibc/raw/v0.9.33.2/extra/scripts/getent /usr/bin/

# Shell library with a collection of functions for entrypoint.sh
ADD --chmod=644 --checksum=sha256:e9f81f8c13f585804b1e37bd2b2e37c8957270bcf2b71d95f24a2e80e4c47813 \
    https://gist.githubusercontent.com/HeavenVolkoff/d3d14669f2786df68dd8a445eed8dd81/raw \
    /usr/local/bin/entrypoint.shlib

COPY --from=busybox /bin/busybox /bin/busybox

RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ln -s /bin/env /usr/bin/env

COPY --chmod=755    rpc.sh          /usr/local/bin/
COPY --chmod=755    entrypoint.sh   /usr/local/bin/
COPY --from=install /srv/           /

EXPOSE $TRANSMISSION_PEER_PORT/tcp $TRANSMISSION_PEER_PORT/udp $TRANSMISSION_RPC_PORT/tcp

VOLUME ["$TRANSMISSION_CONF_DIR", "$TRANSMISSION_WATCH_DIR", "$TRANSMISSION_DOWNLOAD_DIR"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --retries=6 --interval=30s --timeout=10s --start-period=30s \
    CMD rpc.sh session-stats

LABEL org.opencontainers.image.title="Transmission" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.description="A Fast, Easy, and Free BitTorrent Client" \
      version.command="--version 2>&1 | awk -F' ' '{ print \$2 }'" \
      version.entrypoint="transmission-daemon"
