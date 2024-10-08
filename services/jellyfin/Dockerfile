# syntax=docker/dockerfile:1

ARG JELLYFIN_VERSION=10.9.11

FROM jellyfin/jellyfin:${JELLYFIN_VERSION}

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

# Shell library with a collection of functions for entrypoint.sh
ADD --chmod=644 --checksum=sha256:e9f81f8c13f585804b1e37bd2b2e37c8957270bcf2b71d95f24a2e80e4c47813 \
    https://gist.githubusercontent.com/HeavenVolkoff/d3d14669f2786df68dd8a445eed8dd81/raw \
    /usr/local/bin/entrypoint.shlib

COPY --chmod=755    entrypoint.sh   /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

LABEL org.opencontainers.image.title="Jellyfin" \
      org.opencontainers.image.version="${JELLYFIN_VERSION}" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.description="The Free Software Media System"
