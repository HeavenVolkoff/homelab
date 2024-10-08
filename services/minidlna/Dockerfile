# syntax=docker/dockerfile:1

# === Stage 0 - Cross-compilation helper =======================================
FROM --platform=$BUILDPLATFORM docker.io/tonistiigi/xx:latest AS xx

# === Stage 1 - Builder ========================================================
FROM --platform=$BUILDPLATFORM docker.io/library/alpine:3 AS builder

ARG TARGETPLATFORM

COPY --from=xx / /

RUN --mount=type=cache,target=/var/cache/apk \
    --mount=type=cache,target=/etc/apk/cache \
    apk add \
        git \
        lld \
        bash \
        llvm \
        clang \
        pkgconf \
        gettext-dev \
        autoconf \
        automake \
        build-base \
    && \
    xx-apk \
        add \
        gcc \
        musl-dev \
        libc-dev \
        flac-dev \
        zlib-dev \
        libogg-dev \
        sqlite-dev \
        ffmpeg-dev \
        gettext-dev \
        libexif-dev \
        libid3tag-dev \
        libvorbis-dev \
        libjpeg-turbo-dev \
        bsd-compat-headers \
        ffmpegthumbnailer-dev


# ldd drop-in replacement for cross-compilation toolchains
ADD --chmod=755 --checksum=sha256:02d15b2ab0dcdfc462be75c237fe629cf45d828670183ac5e9bf3b7690a991e4 \
    https://gist.githubusercontent.com/jerome-pouiller/c403786c1394f53f44a3b61214489e6f/raw \
    /usr/local/bin/ldd

# Patch ldd script to work with xx and llvm tools
RUN sed -i 's/gcc="${prefix}-gcc"/gcc="xx-clang"/' /usr/local/bin/ldd \
    && sed -i 's/readelf="${prefix}-readelf"/readelf="llvm-readelf"/' /usr/local/bin/ldd

WORKDIR /srv/minidlna

ADD https://github.com/NathanaelA/minidlna/archive/33da136af3.tar.gz minidlna.tar.gz

RUN tar -xzf minidlna.tar.gz --strip-components=1

WORKDIR /srv/minidlna

COPY *.patch ./

RUN for file in *.patch; do patch -F5 -lp1 -d . -t <"$file"; done

RUN mkdir -p /opt/minidlna

RUN xx-clang --setup-target-triple

ENV CC=xx-clang \
    FFLAGS="-fasynchronous-unwind-tables -fexceptions -fstack-protector-strong -fcf-protection -fno-semantic-interposition -fstack-check -fstack-clash-protection" \
    CFLAGS="-O2 -pipe -Wall -Werror=format-security -fPIC -D_FORTIFY_SOURCE=2 -fcommon -D_LARGEFILE64_SOURCE=1 ${FFLAGS}" \
    LDFLAGS="-pipe -Wl,-z,relro,-z,now,-z,defs ${FFLAGS}"
RUN [ -x configure ] || ./autogen.sh
RUN ac_cv_lib_id3tag__lz___id3_file_open=yes \
    ac_cv_lib_avformat__lavcodec__lavutil__lz___avformat_open_input=yes \
    ac_cv_lib_avformat__lavcodec__lavutil__lz___av_open_input_file=yes \
    bash ./configure \
        --host=$(xx-clang --print-target-triple) \
        --build=$(TARGETPLATFORM= xx-clang --print-target-triple) \
        --prefix=/opt/minidlna \
        --with-pic \
        --enable-lto \
        --enable-thumbnail \
        --disable-debug \
    || { echo "ERROR: Runing configure"; cat config.log; exit 1; }
RUN make -j"$(nproc)"
RUN make install
RUN $(xx-clang --print-target-triple)-strip --strip-unneeded /opt/minidlna/sbin/minidlnad
RUN xx-verify /opt/minidlna/sbin/minidlnad

WORKDIR /srv

RUN set -eux; \
    rm -r minidlna \
    && \
    for _so in $(ldd /opt/minidlna/sbin/minidlnad | awk '{print $3}' | sort | uniq); do \
        if [ -f "$(xx-clang -print-sysroot)${_so}" ]; then \
            install -D -t "/srv$(dirname "$_so")" "$(xx-clang -print-sysroot)${_so}"; \
        fi \
    ; done \
    && \
    install -D -t "/srv/lib" "$(xx-clang -print-sysroot)/lib/ld-musl-aarch64.so.1";

# === Stage 2 - Busybox ========================================================
FROM busybox:stable-musl AS busybox

# === Stage 3 - Runtime ========================================================
FROM gcr.io/distroless/static-debian12

ENV TZ=UTC \
    PUID=1000 \
    PGID=1000 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TMPDIR=/tmp \
    LANGUAGE=en \
    MINIDLNA_DB_DIR=/usr/share/minidlna \
    MINIDLNA_LOG_DIR=/var/log/minidlna

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

COPY --from=builder /srv/           /
COPY --from=builder /opt/minidlna/  /usr/
COPY --chmod=755    entrypoint.sh   /usr/local/bin/

EXPOSE 1900/udp 8200/tcp

VOLUME ["$MINIDLNA_DB_DIR", "$MINIDLNA_LOG_DIR"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --retries=6 --interval=30s --timeout=10s --start-period=30s \
    CMD wget --timeout=1 --tries=1 -q 'localhost:8200' -O /dev/null || exit 1

LABEL org.opencontainers.image.title="minidlna" \
      org.opencontainers.image.authors="Vítor Vasconcellos <vasconcellos.dev@gmail.com>" \
      org.opencontainers.image.revision="1" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.description="Clone of SourceForge MiniDLNA w/ Passwordable folders" \
      version.command="-V | awk -F' ' '{ print \$2 }'" \
      version.entrypoint="minidlnad"
