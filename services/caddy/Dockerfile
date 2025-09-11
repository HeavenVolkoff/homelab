# syntax=docker/dockerfile:1@sha256:38387523653efa0039f8e1c89bb74a30504e76ee9f565e25c9a09841f9427b05

# renovate: datasource=github-releases depName=caddyserver/caddy
ARG CADDY_VERSION='2.10.2'

# === Stage 0 - Cross-compilation helper =======================================
FROM --platform=$BUILDPLATFORM docker.io/tonistiigi/xx:latest@sha256:010d4b66aed389848b0694f91c7aaee9df59a6f20be7f5d12e53663a37bd14e2 AS xx

# === Stage 1.1 - Shoko ========================================================
FROM --platform=$BUILDPLATFORM docker.io/shokoanime/server:daily@sha256:c0cd1e9cad0dbefd63d29e93f8eed1e65a52499d288ed8c27070c7e861234daf AS shoko

# === Stage 1.2 - Flood ========================================================
FROM --platform=$BUILDPLATFORM docker.io/jesec/flood:4.9.5@sha256:1a603b5e867aa0018bb1a86882d537469f1ca0cee2860fb3f442cae4445888f6 AS flood

# === Stage 1.3 - Jellyfin =====================================================
FROM --platform=$BUILDPLATFORM docker.io/jellyfin/jellyfin:10.10.7@sha256:7ae36aab93ef9b6aaff02b37f8bb23df84bb2d7a3f6054ec8fc466072a648ce2 AS jellyfin

# === Stage 1.4 - Vaultwarden ==================================================
FROM --platform=$BUILDPLATFORM docker.io/vaultwarden/server:1.34.3@sha256:84fd8a47f58d79a1ad824c27be0a9492750c0fa5216b35c749863093bfa3c3d7 AS vaultwarden

# === Stage 2 - Builder ========================================================
FROM --platform=$BUILDPLATFORM docker.io/caddy:2.10-builder@sha256:13bf132b50ab5a3abd4d62d4da27a9d8fd98818028746fe85e745d73e3e71f3d AS builder

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

FROM --platform=$BUILDPLATFORM docker.io/library/alpine:3@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1 AS static

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

FROM docker.io/library/busybox:stable-musl@sha256:74322b4716a11835c6f413fe9ffc2608ffdb8452f51cad9514a2b804908dc16e AS busybox

#--

FROM gcr.io/distroless/static-debian12@sha256:87bce11be0af225e4ca761c40babb06d6d559f5767fbf7dc3c47f0f1a466b92c

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
