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
create group flood "${PUID}"
create passwd flood "${PGID}"

echo "Configure timezone"
cfg_tz "${TZ:-UTC}"

echo "Create flood's data directory"
mkdir -p "$FLOOD_DATA_DIR"
ln -fs "$FLOOD_DATA_DIR/temp" "$(mktemp -d)"

if [ -n "${FLOOD_ALLOWED_DIRS:-}" ]; then
  (
    IFS=,
    for _allowed_path in $FLOOD_ALLOWED_DIRS; do
      if [ -d "${_allowed_path}" ]; then
        echo "Fix permissions for: $_allowed_path"
        chown flood:flood "$_allowed_path"
      else
        echo "Allowed path is not a directory: $_allowed_path" 1>&2
        exit 1
      fi
    done
  )

  set -- --allowedpath="${FLOOD_ALLOWED_DIRS}" "$@"
fi

echo "Fix flood's directories permissions"
# this will cause less disk access than `chown -R`
find "$FLOOD_DATA_DIR" \! -user flood -exec chown flood: '{}' +

exec su flood -s /usr/local/bin/flood -- --rundir="$FLOOD_DATA_DIR" "$@"
