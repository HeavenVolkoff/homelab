# syntax=docker/dockerfile:1@sha256:38387523653efa0039f8e1c89bb74a30504e76ee9f565e25c9a09841f9427b05

# === Stage 0 - Disambiguation =================================================
FROM gcr.io/distroless/cc-debian12:debug@sha256:dfa99a8ef08227e4661dab7b357ca9952f17288ae745884ea3e7a5150bfcc585 AS disambiguation

# Setup busybox symlinks
RUN [ "/busybox/ln", "-s", "/busybox/sh", "/bin/sh" ]
RUN [ "/busybox/ln", "-s", "/busybox/env", "/usr/bin/env" ]

RUN find / -type f -name '*.so*' | sort | uniq > /libs.txt

# === Stage 1 - Vaultwarden ====================================================
FROM docker.io/vaultwarden/server:1.34.3@sha256:84fd8a47f58d79a1ad824c27be0a9492750c0fa5216b35c749863093bfa3c3d7 AS vaultwarden

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
FROM docker.io/library/busybox:stable-musl@sha256:74322b4716a11835c6f413fe9ffc2608ffdb8452f51cad9514a2b804908dc16e AS busybox

# === Stage 3 - Runtime ========================================================
FROM gcr.io/distroless/cc-debian12@sha256:bf0494952368db47e9e38eecc325c33f5ee299b1b1ccc5d9e30bdf1e5e4e3a58

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
      org.opencontainers.image.description="Unofficial Bitwarden compatible server written in Rust"
