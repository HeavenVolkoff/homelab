#!/usr/bin/env sh

set -eu

# Shortcircuit for non-default commands.
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
create group vaultwarden "${PUID}"
create passwd vaultwarden "${PGID}"

echo "Configure timezone"
cfg_tz "${TZ:-UTC}"

echo "Fix Vaultwarden directories permissions"
find /data \! -user vaultwarden -exec chown vaultwarden: '{}' +

# Drop privileges
exec su vaultwarden -s /usr/local/bin/vaultwarden -- "$@"
