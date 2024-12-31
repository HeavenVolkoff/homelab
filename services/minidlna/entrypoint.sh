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
create group minidlna "${PUID}"
create passwd minidlna "${PGID}"

echo "Configure timezone"
cfg_tz "${TZ:-UTC}"

echo "Create minidlna log and database directories"
mkdir -p "$MINIDLNA_DB_DIR" "$MINIDLNA_LOG_DIR"

echo "Generate minidlna's configuration from environment variables"
: >/etc/minidlna.conf
for _envvar in $(env); do
  if expr "$_envvar" : 'MINIDLNA_' 1>/dev/null; then
    minidlna_value="$(echo "$_envvar" | sed -r 's/.*=(.*)/\1/g')"
    if expr "$_envvar" : 'MINIDLNA_MEDIA_DIR' 1>/dev/null; then
      minidlna_name='media_dir'
      _dir="$(echo "$minidlna_value" | cut -d, -f2)"
      if [ -d "$_dir" ]; then
        echo "Fix permissions for: $_dir"
        # this will cause less disk access than `chown -R`
        find "$_dir" \! -user minidlna -exec chown minidlna: '{}' +
      else
        echo "Invalid media directory: ${_dir} not a directory" 1>&2
        exit 1
      fi
    else
      minidlna_name="$(
        echo "$_envvar" \
          | sed -r 's/MINIDLNA_(.*)=.*/\1/g' \
          | tr '[:upper:]' '[:lower:]'
      )"
    fi
    echo "${minidlna_name}=${minidlna_value}" >>/etc/minidlna.conf
  fi
done

# Reset old pid if it exists
: >"/run/minidlna.pid"

echo "Fix minidlna's directories permissions"
for path in "$MINIDLNA_DB_DIR" "$MINIDLNA_LOG_DIR" /run/minidlna.pid; do
  if [ -d "$path" ]; then
    # this will cause less disk access than `chown -R`
    find "$path" \! -user minidlna -exec chown minidlna: '{}' +
  else
    chown minidlna: "$path"
  fi
done

# Start daemon
exec su minidlna -s /usr/sbin/minidlnad -- -P "/run/minidlna.pid" -S "$@"
