# syntax=docker/dockerfile:1

ARG VAULWARDEN_VERSION=1.32.7

# === Stage 0 - Disambiguation =================================================
FROM gcr.io/distroless/cc-debian12:debug AS disambiguation

# Setup busybox symlinks
RUN [ "/busybox/ln", "-s", "/busybox/sh", "/bin/sh" ]
RUN [ "/busybox/ln", "-s", "/busybox/env", "/usr/bin/env" ]

RUN find / -type f -name '*.so*' | sort | uniq > /libs.txt

# === Stage 1 - Vaultwarden ====================================================
FROM docker.io/vaultwarden/server:${VAULWARDEN_VERSION} as vaultwarden

# Don't allow APT to make question
ARG DEBIAN_FRONTEND=noninteractive

# http://stackoverflow.com/questions/48162574/ddg#49462622
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

# Configure apt
COPY --from=utilities apt.conf /etc/apt/apt.conf.d/99docker-apt-config
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN rm -f /etc/apt/apt.conf.d/docker-clean

# Update dependencies
RUN --mount=type=cache,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,sharing=locked,target=/var/lib/apt \
    set -xeu \
    && \
    apt-get update \
    && \
    apt-get full-upgrade

# Patch healtcheck.sh to use wget instead of curl
RUN sed -i 's/curl --insecure --fail --silent --show-error/wget --no-check-certificate --timeout=1 --tries=1 -q -O \/dev\/null/g' /healthcheck.sh

COPY --from=disambiguation /libs.txt ./

RUN set -eux; \
    for _bin in "$(realpath "$(command -v /vaultwarden)")"; do \
        for _so in $( \
            ldd "$_bin" | awk '{print $3}' | sort | uniq | comm -23 - ./libs.txt \
        ); do \
            if [ -f "$_so" ]; then \
                install -D -t "/srv$(dirname "$_so")" $_so; \
            fi \
        ; done \
        && \
        install -D -t /srv/usr/local/bin/ "$_bin" \
    ; done

# === Stage 2 - Busybox ========================================================
FROM busybox:stable-musl AS busybox

# === Stage 3 - Runtime ========================================================
FROM gcr.io/distroless/cc-debian12

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
    WEB_VAULT_ENABLED=false \
    ROCKET_PROFILE=release \
    ROCKET_ADDRESS=:: \
    ROCKET_PORT=8080

COPY --from=busybox /bin/busybox /bin/busybox

RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ln -s /bin/env /usr/bin/env

COPY                  entrypoint.sh    /usr/local/bin/
COPY --from=utilities getent.sh        /usr/local/bin/getent
COPY --from=utilities entrypoint.shlib /usr/local/bin/

COPY --from=vaultwarden /srv/           /
COPY --from=vaultwarden /healthcheck.sh /usr/local/bin/

EXPOSE $ROCKET_PORT/tcp

VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --retries=6 --interval=30s --timeout=10s --start-period=30s \
    CMD healthcheck.sh

LABEL org.opencontainers.image.title="Vaultwarden" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.description="Unofficial Bitwarden compatible server written in Rust" \
      version.command="--version | awk -F' ' '{ print \$2 }' | head -n1" \
      version.entrypoint="vaultwarden"
