# syntax=docker/dockerfile:1

# renovate: datasource=docker packageName=jellyfin/jellyfin
ARG JELLYFIN_VERSION=10.10.3

FROM docker.io/jellyfin/jellyfin:${JELLYFIN_VERSION}

ARG JELLYFIN_VERSION

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
      org.opencontainers.image.version="${JELLYFIN_VERSION}" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.description="The Free Software Media System"
