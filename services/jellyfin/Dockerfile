# syntax=docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6

FROM docker.io/jellyfin/jellyfin:10.11.0@sha256:59417f441213e236a9f907d4e71a13472042409d85f9e9310dbdd87ee33d7bd4

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
    JELLYFIN_LOG_DIR=/var/log \
    JELLYFIN_DATA_DIR=/usr/share/jellyfin \
    JELLYFIN_CACHE_DIR=/var/cache/jellyfin \
    JELLYFIN_MEDIA_DIR=/media \
    JELLYFIN_CONFIG_DIR=/etc/jellyfin \
    JELLYFIN_TRANSCODE_DIR=/tmp/transcodes

COPY                  entrypoint.sh    /usr/local/bin/
COPY --from=utilities entrypoint.shlib /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

LABEL org.opencontainers.image.title="Jellyfin" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.description="The Free Software Media System"
