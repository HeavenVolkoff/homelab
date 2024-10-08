# syntax=docker/dockerfile:1

# === Stage 0 - Disambiguation =================================================
FROM gcr.io/distroless/nodejs22-debian12:debug AS disambiguation

# Setup busybox symlinks
RUN [ "/busybox/ln", "-s", "/busybox/sh", "/bin/sh" ]
RUN [ "/busybox/ln", "-s", "/busybox/env", "/usr/bin/env" ]

RUN find / -type f -name '*.so*' | sort | uniq > /libs.txt

# === Stage 1 - Install Flood ==================================================
FROM docker.io/library/node:22-bookworm AS install

# Don't allow APT to make question
ARG DEBIAN_FRONTEND=noninteractive

# http://stackoverflow.com/questions/48162574/ddg#49462622
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

# Configure apt
ADD --chmod=644 --checksum=sha256:8bea540b2cd1a47c94555e746c75fd41a42847a46d8c8c36c7ab6dd9c8526ab4 \
    https://gist.githubusercontent.com/HeavenVolkoff/ff7b77b9087f956b8df944772e93c071/raw \
    /etc/apt/apt.conf.d/99docker-apt-config
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN rm -f /etc/apt/apt.conf.d/docker-clean

# Install dependencies
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    set -xeu \
    && \
    apt-get update \
    && \
    apt-get full-upgrade \
    && \
    apt-get install mediainfo

COPY --from=disambiguation /libs.txt ./

RUN set -eux; \
    for _bin in "$(realpath "$(command -v mediainfo)")"; do \
        for _so in $( \
            ldd "$_bin" | awk '{print $3}' | sort | uniq | comm -23 - ./libs.txt \
        ); do \
            if [ -f "$_so" ]; then \
                install -D -t "/srv$(dirname "$_so")" $_so; \
            fi \
        ; done \
        && \
        install -D -t /srv/usr/bin/ "$_bin" \
    ; done

# Cache burst
ADD https://api.github.com/repos/jesec/flood/releases info.json

# Install flood
RUN --mount=type=cache,target=/root/.npm \
    npm i -g flood

# === Stage 2 - Busybox ========================================================
FROM busybox:stable-musl AS busybox

# === Stage 3 - Runtime ========================================================
FROM gcr.io/distroless/nodejs22-debian12

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
	NODE_ENV=production \
    FLOOD_DATA_DIR=/usr/share/flood

# Tool to parse /etc/passwd
ADD --chmod=755 --checksum=sha256:a99beabea22571cfad4f77422e5d3ed922d9490232d94cb87cf32956766bc42a \
    https://github.com/kraj/uClibc/raw/v0.9.33.2/extra/scripts/getent /usr/bin/

# Shell library with a collection of functions for entrypoint.sh
ADD --chmod=644 --checksum=sha256:e9f81f8c13f585804b1e37bd2b2e37c8957270bcf2b71d95f24a2e80e4c47813 \
    https://gist.githubusercontent.com/HeavenVolkoff/d3d14669f2786df68dd8a445eed8dd81/raw \
    /usr/local/bin/entrypoint.shlib

COPY --from=busybox /bin/busybox /bin/busybox

RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ln -s /bin/env /usr/bin/env

COPY --from=install /usr/local/lib/node_modules/flood   /usr/local/lib/node_modules/flood
COPY --from=install /srv/                               /
COPY --chmod=755    entrypoint.sh                       /usr/local/bin/

RUN ln -s /nodejs/bin/node /usr/local/bin/node \
    && ln -s ../lib/node_modules/flood/dist/index.js /usr/local/bin/flood

EXPOSE 3000/tcp

VOLUME ["$FLOOD_DATA_DIR"]

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

LABEL org.opencontainers.image.title="Flood" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="10" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.description="A modern web UI for various torrent clients with a Node.js backend and React frontend" \
      version.entrypoint="flood" \
      version.command="--version"

