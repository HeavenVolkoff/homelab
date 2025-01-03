# syntax=docker/dockerfile:1

# renovate: datasource=docker packageName=caddy/caddy
ARG CADDY_VERSION=2.8.4

# === Stage 0 - Cross-compilation helper =======================================
FROM --platform=$BUILDPLATFORM docker.io/tonistiigi/xx:latest AS xx

# === Stage 1.1 - Flood ========================================================
FROM --platform=$BUILDPLATFORM jesec/flood:4.8.5 AS flood

# === Stage 1.2 - Jellyfin =====================================================
FROM --platform=$BUILDPLATFORM jellyfin/jellyfin:10.10.3 AS jellyfin

# === Stage 1.3 - Vaultwarden ==================================================
FROM --platform=$BUILDPLATFORM docker.io/vaultwarden/server:1.32.7 AS vaultwarden

# === Stage 2 - Builder ========================================================
FROM --platform=$BUILDPLATFORM docker.io/caddy/caddy:${CADDY_VERSION}-builder-alpine AS builder

ARG TARGETPLATFORM

COPY --from=xx / /

ENV CADDY_VERSION ${CADDY_VERSION}

RUN env CGO_ENABLED=0 XCADDY_WHICH_GO=xx-go xcaddy build \
    --output /bin/caddy \
    --with github.com/pberkel/caddy-storage-redis \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    && \
    xx-verify /bin/caddy

#--

FROM --platform=$BUILDPLATFORM docker.io/library/alpine:3 AS static

RUN apk add --no-cache jq curl file pigz zstd brotli mailcap moreutils libarchive-tools

COPY                    ./static                                        /var/www/homepage
COPY --from=flood       /usr/local/lib/node_modules/flood/dist/assets   /var/www/flood
COPY --from=jellyfin    /jellyfin/jellyfin-web                          /var/www/jellyfin
COPY --from=vaultwarden /web-vault                                      /var/www/vaultwarden

# Pull lastest Shoko webui version from upstream
RUN set -eu; \
    mkdir -p /var/www/shoko \
    && \
    curl -LSs "$( \
        while { \
            i=$((${i--1}+1)); \
            ! curl -L#sS 'https://api.github.com/repos/ShokoAnime/ShokoServer-WebUI/releases?per_page=100&page='$i \
              | jq -r 'if . | length == 0 then error("Empty") else . | .[0].assets[0]["browser_download_url"] end'; \
        }; do sleep 1; done \
    )" \
    | bsdtar -xf- -C /var/www/shoko/

# https://docs.fastly.com/en/guides/enabling-automatic-gzipping
RUN find /var/www -type f -regex '.*\.\(js\|css\|xml\|txt\|html\|json\|ico\|svg\|eot\|otf\|ttf\)' \
    -not -wholename '/var/www/homepage/index.html' \
    -exec zstd --adapt -q -T0 {} \+ \
    -exec brotli --best {} \+ \
    -exec pigz -k --best {} \+

# Generate a hash query parameter for cache burst
RUN set -eu; \
    cd /var/www/homepage && \
    awk "{$( \
        find assets/ -type f -exec printf '"%s"\n' {} \; \
        | xargs sh -c ' \
            for file in "$@"; do \
                printf "sub("\""%s"\"","\""%s?hash=%s"\"");" "$file" "$file" "$(sha1sum "$file" | cut -c-10)"; \
            done \
        ' sh \
    )}; { print }" index.html | sponge index.html

#--

FROM docker.io/library/busybox:stable-musl AS busybox

#--

FROM gcr.io/distroless/static-debian12

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
    CADDY_VERSION=${CADDY_VERSION} \
    XDG_DATA_HOME=/usr/share \
    XDG_CONFIG_HOME=/etc

COPY --from=busybox /bin/busybox /bin/busybox

RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ln -s /bin/env /usr/bin/env

COPY                  entrypoint.sh    /usr/local/bin/
COPY --from=utilities getent.sh        /usr/local/bin/getent
COPY --from=utilities entrypoint.shlib /usr/local/bin/

COPY --from=static    /var/www         /var/www
COPY --from=static    /etc/mime.types  /etc/mime.types
COPY --from=builder   /bin/caddy       /bin/caddy
COPY --from=busybox   /bin/busybox     /bin/busybox

EXPOSE 80/tcp 443/tcp 2019/tcp

VOLUME ["/usr/share/caddy", "/etc/caddy"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["docker-proxy"]

LABEL org.opencontainers.image.title="Caddy" \
    org.opencontainers.image.version="${CADDY_VERSION}" \
    org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
    org.opencontainers.image.revision="1" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.description="A powerful, enterprise-ready, open source web server with automatic HTTPS written in Go"
