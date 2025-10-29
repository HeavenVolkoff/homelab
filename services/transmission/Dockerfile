# syntax=docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6

# === Stage 0 - Install Transmission ===========================================
FROM docker.io/library/alpine:edge@sha256:115729ec5cb049ba6359c3ab005ac742012d92bbaa5b8bc1a878f1e8f62c0cb8 AS install

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
FROM docker.io/library/busybox:stable-musl@sha256:47909e6a7d1773157732ac28b2062decdb47ff106a485ef48e2d19a27e4f515b AS busybox

# === Stage 2 - Runtime ========================================================
FROM gcr.io/distroless/static-debian12@sha256:87bce11be0af225e4ca761c40babb06d6d559f5767fbf7dc3c47f0f1a466b92c

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

COPY --from=busybox /bin/busybox /bin/busybox

RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ln -s /bin/env /usr/bin/env

COPY                  entrypoint.sh    /usr/local/bin/
COPY --from=utilities getent.sh        /usr/local/bin/getent
COPY --from=utilities entrypoint.shlib /usr/local/bin/

COPY                rpc.sh          /usr/local/bin/
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
