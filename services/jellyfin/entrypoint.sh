#!/usr/bin/env sh

set -eu

# Short-circuit for non-default commands.
# The last part inside the "{}" is a workaround for the following bug in ash/dash:
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=874264
if [ -n "${1:-}" ] \
  && [ "${1#-}" = "${1}" ] \
  && [ -n "$(command -v -- "${1}")" ] \
  && { ! [ -f "${1}" ] || [ -x "${1}" ]; }; then
  exec "$@"
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "This container requires executing as root for initial setup, privileges are dropped shortly after" 1>&2
  exit 1
fi

# shellcheck disable=SC1090
. "$(dirname -- "$0")/$(basename -- "$0" '.sh').shlib"

echo "Configure unprivileged user"
create group jellyfin "${PUID}"
create passwd jellyfin "${PGID}"

echo "Configure timezone"
cfg_tz "${TZ:-UTC}"

echo "Create jellyfin's directories"
mkdir -p \
  "$JELLYFIN_LOG_DIR" "$JELLYFIN_DATA_DIR" "$JELLYFIN_CACHE_DIR" \
  "$JELLYFIN_MEDIA_DIR" "$JELLYFIN_CONFIG_DIR" "$JELLYFIN_TRANSCODE_DIR"

echo "Configure transcode temporary path"
if [ -f "$JELLYFIN_CONFIG_DIR/encoding.xml" ]; then
  sed -ie \
    's@<TranscodingTempPath>.*</TranscodingTempPath>@<TranscodingTempPath>'"$JELLYFIN_TRANSCODE_DIR"'</TranscodingTempPath>@' \
    "$JELLYFIN_CONFIG_DIR/encoding.xml"
else
  cat <<EOF >"$JELLYFIN_CONFIG_DIR/encoding.xml"
<?xml version="1.0" encoding="utf-8"?>
<EncodingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <TranscodingTempPath>${JELLYFIN_TRANSCODE_DIR}</TranscodingTempPath>
</EncodingOptions>
EOF
fi

echo "Configure Metadata and Cache paths"
if [ -f "$JELLYFIN_CONFIG_DIR/system.xml" ]; then
  sed -ie \
    's@<CachePath>.*</CachePath>@<CachePath>'"$JELLYFIN_CACHE_DIR"'</CachePath>@' \
    "$JELLYFIN_CONFIG_DIR/system.xml"
  sed -ie \
    's@<MetadataPath>.*</MetadataPath>@<MetadataPath>'"$JELLYFIN_DATA_DIR"'/metadata</MetadataPath>@' \
    "$JELLYFIN_CONFIG_DIR/system.xml"
else
  cat <<EOF >"$JELLYFIN_CONFIG_DIR/system.xml"
<?xml version="1.0" encoding="utf-8"?>
<ServerConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <CachePath>${JELLYFIN_CACHE_DIR}</CachePath>
  <MetadataPath>${JELLYFIN_DATA_DIR}/metadata</MetadataPath>
</ServerConfiguration>
EOF
fi

for path in \
  "$JELLYFIN_LOG_DIR" \
  "$JELLYFIN_DATA_DIR" \
  "$JELLYFIN_MEDIA_DIR" \
  "$JELLYFIN_CACHE_DIR" \
  "$JELLYFIN_CONFIG_DIR" \
  "$JELLYFIN_TRANSCODE_DIR"; do
  if [ -d "$path" ]; then
    # this will cause less disk access than `chown -R`
    find "$path" \! -user jellyfin -exec chown jellyfin: '{}' +
  else
    chown jellyfin: "$path"
  fi
done

set -- \
  --logdir "$JELLYFIN_LOG_DIR" \
  --ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg \
  --service \
  --datadir "$JELLYFIN_DATA_DIR" \
  --cachedir "$JELLYFIN_CACHE_DIR" \
  --configdir "$JELLYFIN_CONFIG_DIR" \
  --package-name docker \
  "$@"

if [ -n "${JELLYFIN_URL:-}" ]; then
  set -- "$@" --published-server-url "$JELLYFIN_URL"
fi

# Drop privileges
exec su jellyfin -s /jellyfin/jellyfin -- "$@"
