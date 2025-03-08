# syntax=docker/dockerfile:1@sha256:4c68376a702446fc3c79af22de146a148bc3367e73c25a5803d453b6b3f722fb

# renovate: datasource=github-releases depName=caddyserver/caddy
ARG CADDY_VERSION='2.9.1'

# === Stage 0 - Cross-compilation helper =======================================
FROM --platform=$BUILDPLATFORM docker.io/tonistiigi/xx:latest@sha256:923441d7c25f1e2eb5789f82d987693c47b8ed987c4ab3b075d6ed2b5d6779a3 AS xx

# === Stage 1.1 - Shoko ========================================================
FROM --platform=$BUILDPLATFORM docker.io/shokoanime/server:daily@sha256:8e15d71bb4e391c01ca3187f392d69fed5792f68f8f0bfd7c357dae63b82a1c7 AS shoko

# === Stage 1.2 - Flood ========================================================
FROM --platform=$BUILDPLATFORM docker.io/jesec/flood:4.9.3@sha256:e9c8a3fd460ad1e81b47e7e17ec257a998f4e92e2b8c4935190d63c28e5b9b50 AS flood

# === Stage 1.3 - Jellyfin =====================================================
FROM --platform=$BUILDPLATFORM docker.io/jellyfin/jellyfin:10.10.6@sha256:96b09723b22fdde74283274bdc1f63b9b76768afd6045dd80d4a4559fc4bb7f3 AS jellyfin

# === Stage 1.4 - Vaultwarden ==================================================
FROM --platform=$BUILDPLATFORM docker.io/vaultwarden/server:1.33.2@sha256:87edb99945da91bd7504ac1435495595af2e89ad2c7adc151ae5bf091ec8baf2 AS vaultwarden

# === Stage 2 - Builder ========================================================
FROM --platform=$BUILDPLATFORM docker.io/caddy:2.9-builder@sha256:4c455f2cf685637594f7112b2526229a58a6039975fd1915281d452b2075bda3 AS builder

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

FROM --platform=$BUILDPLATFORM docker.io/library/alpine:3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c AS static

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

FROM docker.io/library/busybox:stable-musl@sha256:52931c5795db81b02f89211b300630477f851870b5504d6883c7c38f99f4e692 AS busybox

#--

FROM gcr.io/distroless/static-debian12@sha256:3f2b64ef97bd285e36132c684e6b2ae8f2723293d09aae046196cca64251acac

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
