# syntax=docker/dockerfile:1@sha256:9857836c9ee4268391bb5b09f9f157f3c91bb15821bb77969642813b0d00518d

# renovate: datasource=github-releases depName=HeavenVolkoff/minidlna-build versioning=semver-coerced
ARG MINIDLNA_VERSION='1.3.3+p.1'

# === Stage 0 - Install MiniDLNA ===============================================
FROM --platform=$BUILDPLATFORM docker.io/library/busybox:stable-musl@sha256:5c16ec53d312df1867044cc90abd951bf37fdad32cc9b4a1e1e25d2f8eaf343c AS install

ARG TARGETPLATFORM MINIDLNA_VERSION

ENV MINIDLNA_URL=https://github.com/HeavenVolkoff/minidlna-build/releases/download \
    MINIDLNA_VERSION=${MINIDLNA_VERSION}

WORKDIR /opt/minidlna
RUN case "$TARGETPLATFORM" in \
        "linux/arm64") \
            wget -qO- "${MINIDLNA_URL}/${MINIDLNA_VERSION}/minidlna-aarch64-linux-gnu.tar.xz" \
            | tar -xJ -C . ;; \
        "linux/amd64") \
            wget -qO- "${MINIDLNA_URL}/${MINIDLNA_VERSION}/minidlna-x86_64-linux-gnu.tar.xz" \
            | tar -xJ -C . ;; \
        *) \
            echo "Unsupported architecture"; exit 1 ;; \
    esac

# === Stage 1 - Busybox ========================================================
FROM docker.io/library/busybox:stable-musl@sha256:5c16ec53d312df1867044cc90abd951bf37fdad32cc9b4a1e1e25d2f8eaf343c AS busybox

# === Stage 2 - Runtime ========================================================
FROM gcr.io/distroless/base-nossl-debian12@sha256:1202f767cf810c5bc5f30b95babc268a37eaa1e6fbacd35bed2c924f1bb2a234

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
    MINIDLNA_DB_DIR=/usr/share/minidlna \
    MINIDLNA_LOG_DIR=/var/log/minidlna

COPY --from=busybox /bin/busybox /bin/busybox

RUN ["/bin/busybox", "--install", "-s", "/bin"]
RUN ln -s /bin/env /usr/bin/env

COPY                  entrypoint.sh    /usr/local/bin/
COPY --from=utilities getent.sh        /usr/local/bin/getent
COPY --from=utilities entrypoint.shlib /usr/local/bin/

COPY --from=install /opt/minidlna/  /usr/

EXPOSE 1900/udp 8200/tcp

VOLUME ["$MINIDLNA_DB_DIR", "$MINIDLNA_LOG_DIR"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --retries=6 --interval=30s --timeout=10s --start-period=30s \
    CMD wget --timeout=1 --tries=1 -q 'localhost:8200' -O /dev/null || exit 1

LABEL org.opencontainers.image.title="minidlna" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.description="Clone of SourceForge MiniDLNA w/ Passwordable folders"
