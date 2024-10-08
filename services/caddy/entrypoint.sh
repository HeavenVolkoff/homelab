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
create group caddy "${PUID}"
create passwd caddy "${PGID}"
add2group caddy caddy

echo "Configure timezone"
cfg_tz "${TZ:-UTC}"

echo "Fix caddy's directories permissions"
for path in /usr/share/caddy /etc/caddy /var/www /etc/mime.types; do
  if [ -d "$path" ]; then
    # this will cause less disk access than `chown -R`
    find "$path" \! -user caddy -exec chown caddy: '{}' +
  else
    chown caddy: "$path"
  fi
done

exec su caddy -s /bin/caddy -- "$@"
