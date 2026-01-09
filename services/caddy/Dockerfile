# syntax=docker/dockerfile:1@sha256:b6afd42430b15f2d2a4c5a02b919e98a525b785b1aaff16747d2f623364e39b6

# cSpell:ignore xcaddy moreutils webui

# renovate: datasource=github-releases depName=caddyserver/caddy
ARG CADDY_VERSION='2.10.2'

# === Stage 0 - Cross-compilation helper =======================================
FROM --platform=$BUILDPLATFORM docker.io/tonistiigi/xx:latest@sha256:c64defb9ed5a91eacb37f96ccc3d4cd72521c4bd18d5442905b95e2226b0e707 AS xx

# === Stage 1.1 - Shoko ========================================================
FROM --platform=$BUILDPLATFORM docker.io/shokoanime/server:daily@sha256:a88d7563f6a21f5ebead4abcbc83d06e27bd4be563c18a7128f51d8d7717dd28 AS shoko

# === Stage 1.2 - Flood ========================================================
FROM --platform=$BUILDPLATFORM docker.io/jesec/flood:4.11.0@sha256:4b92628572d0b4ff740ca2d1e0262cf8e368cd39aa9e693a6dc2f681d71aadd2 AS flood

# === Stage 1.3 - Jellyfin =====================================================
FROM --platform=$BUILDPLATFORM docker.io/jellyfin/jellyfin:10.11.5@sha256:6d819e9ab067efcf712993b23455cc100ee5585919bb297ea5a109ac00cb626e AS jellyfin

# === Stage 1.4 - Vaultwarden ==================================================
FROM --platform=$BUILDPLATFORM docker.io/vaultwarden/server:1.35.2@sha256:d89a6d21e361254670c24a4272b4b5f245e402c284f2f55de2c379fdbcfa1fa5 AS vaultwarden

# === Stage 2 - Builder ========================================================
FROM --platform=$BUILDPLATFORM docker.io/caddy:2.11-builder@sha256:5fa9a318e2f32bf2c75f59eb4bad9b3e1b8522fbce9a689a6a7d4614145672f3 AS builder

ARG TARGETPLATFORM CADDY_VERSION

COPY --from=xx / /

ENV CADDY_VERSION="v${CADDY_VERSION}"

RUN env CGO_ENABLED=0 XCADDY_WHICH_GO=xx-go xcaddy build \
    --output /bin/caddy \
    --with github.com/pberkel/caddy-storage-redis \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2 \
    && \
    xx-verify /bin/caddy

#--

FROM --platform=$BUILDPLATFORM docker.io/library/alpine:3@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62 AS static

RUN apk add --no-cache jq curl file pigz zstd brotli mailcap moreutils libarchive-tools

COPY                    ./static                                        /var/www/homepage
COPY --from=shoko       /usr/src/app/build/webui                        /var/www/shoko
COPY --from=flood       /usr/local/lib/node_modules/flood/dist/assets   /var/www/flood
COPY --from=jellyfin    /jellyfin/jellyfin-web                          /var/www/jellyfin
COPY --from=vaultwarden /web-vault                                      /var/www/vaultwarden

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

FROM docker.io/library/busybox:stable-musl@sha256:c29b078aeeb7cdc487cf52dc87a69dac71499937f498b35cb606c7943bc412c9 AS busybox

#--

FROM gcr.io/distroless/static-debian12@sha256:4b2a093ef4649bccd586625090a3c668b254cfe180dee54f4c94f3e9bd7e381e

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
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
    org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
    org.opencontainers.image.revision="1" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.description="A powerful, enterprise-ready, open source web server with automatic HTTPS written in Go"
