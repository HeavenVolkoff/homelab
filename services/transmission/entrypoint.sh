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
create group transmission "${PUID}"
create passwd transmission "${PGID}"

echo "Configure timezone"
cfg_tz "${TZ:-UTC}"

echo "Create transmission's configuration directory"
mkdir -p "$TRANSMISSION_CONF_DIR"

echo "Generate transmission's settings.json from environment variables"
TRANSMISSION_SETTINGS="${TRANSMISSION_CONF_DIR}/settings.json"

# Truncate file
: >"$TRANSMISSION_SETTINGS"

echo '{' >>"$TRANSMISSION_SETTINGS"

_blocklist=0
if [ -n "${TRANSMISSION_BLOCKLIST_URL:-}" ]; then
  if wget --spider -q --no-check-certificate "$TRANSMISSION_BLOCKLIST_URL"; then
    _blocklist=1
    cat <<EOF >>"$TRANSMISSION_SETTINGS"
  "blocklist-url": "$TRANSMISSION_BLOCKLIST_URL",
  "blocklist-enabled": true,
EOF
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_BLOCKLIST_URL: ${TRANSMISSION_BLOCKLIST_URL}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_PREALLOCATION:-}" ]; then
  if [ "$TRANSMISSION_PREALLOCATION" -gt 0 ] && [ "$TRANSMISSION_PREALLOCATION" -lt 3 ]; then
    echo "\"preallocation\": ${TRANSMISSION_PREALLOCATION}," >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_PREALLOCATION: ${TRANSMISSION_PREALLOCATION}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_UMASK:-}" ]; then
  TRANSMISSION_UMASK="$(printf '"%03d"' "0$TRANSMISSION_UMASK")"
  echo "\"umask\": ${TRANSMISSION_UMASK}," >>"$TRANSMISSION_SETTINGS"
fi

if [ -n "${TRANSMISSION_WATCH_DIR:-}" ]; then
  if [ -d "$TRANSMISSION_WATCH_DIR" ]; then
    cat <<EOF >>"$TRANSMISSION_SETTINGS"
  "watch-dir": "$TRANSMISSION_WATCH_DIR",
  "watch-dir-enabled": true,
  "trash-original-torrent-files": true,
EOF
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_WATCH_DIR: ${TRANSMISSION_WATCH_DIR}, must be an existing directory" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_CACHE_SIZE:-}" ]; then
  if [ "$TRANSMISSION_CACHE_SIZE" -gt 0 ]; then
    echo "\"cache-size-mb\": ${TRANSMISSION_CACHE_SIZE}," >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_CACHE_SIZE: ${TRANSMISSION_CACHE_SIZE}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_DTH:-}" ]; then
  if [ "$TRANSMISSION_DTH" -eq 1 ]; then
    echo '"dht-enabled": true,' >>"$TRANSMISSION_SETTINGS"
  elif [ "$TRANSMISSION_DTH" -eq 0 ]; then
    echo '"dht-enabled": false,' >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_DTH: ${TRANSMISSION_DTH}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_ENCRYPTION:-}" ]; then
  if [ "$TRANSMISSION_ENCRYPTION" -gt 0 ] && [ "$TRANSMISSION_ENCRYPTION" -lt 3 ]; then
    echo "\"encryption\": ${TRANSMISSION_ENCRYPTION}," >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_ENCRYPTION: ${TRANSMISSION_ENCRYPTION}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_LPD:-}" ]; then
  if [ "$TRANSMISSION_LPD" -eq 1 ]; then
    echo '"lpd-enabled": true,' >>"$TRANSMISSION_SETTINGS"
  elif [ "$TRANSMISSION_LPD" -eq 0 ]; then
    echo '"lpd-enabled": false,' >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_LPD: ${TRANSMISSION_LPD}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_LOG_LEVEL:-}" ]; then
  if [ "$TRANSMISSION_LOG_LEVEL" -gt 0 ] && [ "$TRANSMISSION_LOG_LEVEL" -lt 4 ]; then
    echo "\"message-level\": ${TRANSMISSION_LOG_LEVEL}," >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_LOG_LEVEL: ${TRANSMISSION_LOG_LEVEL}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_PEX:-}" ]; then
  if [ "$TRANSMISSION_PEX" -eq 1 ]; then
    echo '"pex-enabled": true,' >>"$TRANSMISSION_SETTINGS"
  elif [ "$TRANSMISSION_PEX" -eq 0 ]; then
    echo '"pex-enabled": false,' >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_LPD: ${TRANSMISSION_LPD}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_PREFETCH:-}" ]; then
  if [ "$TRANSMISSION_PREFETCH" -eq 1 ]; then
    echo '"prefetch-enabled": true,' >>"$TRANSMISSION_SETTINGS"
  elif [ "$TRANSMISSION_PREFETCH" -eq 0 ]; then
    echo '"prefetch-enabled": false,' >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_PREFETCH: ${TRANSMISSION_PREFETCH}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_UTP:-}" ]; then
  if [ "$TRANSMISSION_UTP" -eq 1 ]; then
    echo '"utp-enabled": true,' >>"$TRANSMISSION_SETTINGS"
  elif [ "$TRANSMISSION_UTP" -eq 0 ]; then
    echo '"utp-enabled": false,' >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_UTP: ${TRANSMISSION_UTP}" 1>&2
  fi
fi

if [ -n "${TRANSMISSION_PEER_LIMIT_GLOBAL:-}" ]; then
  if [ "$TRANSMISSION_PEER_LIMIT_GLOBAL" -gt 0 ]; then
    echo "\"peer-limit-global\": ${TRANSMISSION_PEER_LIMIT_GLOBAL}," >>"$TRANSMISSION_SETTINGS"
  else
    echo "WARNING: Ignoring invalid value for TRANSMISSION_PEER_LIMIT_GLOBAL: ${TRANSMISSION_PEER_LIMIT_GLOBAL}" 1>&2
  fi
fi

if [ "${TRANSMISSION_TCP_LP:-0}" -eq 1 ]; then
  if grep -q 'lp' /proc/sys/net/ipv4/tcp_allowed_congestion_control; then
    echo '"peer-socket-tos": "lowcost",' >>"$TRANSMISSION_SETTINGS"
    echo '"peer-congestion-algorithm": "lp",' >>"$TRANSMISSION_SETTINGS"
  else
    cat <<EOF 1>&2
WARNING: TCP-LP is not available in your system
To enabled it execute:
$> modprobe tcp_lp
And run this container with this option:
--sysctl net.ipv4.tcp_allowed_congestion_control='cubic reno lp'
EOF
  fi
fi

if [ "${TRANSMISSION_PEER_PORT:-0}" -gt 0 ] && [ "$TRANSMISSION_PEER_PORT" -lt 65536 ]; then
  echo '"port-forwarding-enabled": false,' >>"$TRANSMISSION_SETTINGS"
  echo "\"peer-port\": ${TRANSMISSION_PEER_PORT}," >>"$TRANSMISSION_SETTINGS"
else
  echo '"port-forwarding-enabled": true,' >>"$TRANSMISSION_SETTINGS"
  echo '"peer-port-random-on-start": true,' >>"$TRANSMISSION_SETTINGS"
fi

if [ "${TRANSMISSION_RPC_PORT:-0}" -eq 0 ]; then
  echo '"rpc-enabled": false,' >>"$TRANSMISSION_SETTINGS"
  echo "Disabling RPC. Please specify TRANSMISSION_RPC_PORT if you want to enable it."
elif [ "$TRANSMISSION_RPC_PORT" -gt 0 ] && [ "$TRANSMISSION_RPC_PORT" -lt 65536 ]; then
  if [ -z "${TRANSMISSION_RPC_USER:-}" ] || [ -z "${TRANSMISSION_RPC_PASSWORD:-}" ]; then
    echo "ERROR: RPC requires a valid user/password" 1>&2
    exit 1
  fi

  if [ "$(echo "$TRANSMISSION_RPC_PASSWORD" | cut -c1)" = "{" ]; then
    echo "ERROR: RPC password must NOT start with the character {" 1>&2
    exit 1
  fi

  cat <<EOF >>"$TRANSMISSION_SETTINGS"
"rpc-port": ${TRANSMISSION_RPC_PORT},
"rpc-username": "$TRANSMISSION_RPC_USER",
"rpc-password": "$TRANSMISSION_RPC_PASSWORD",
"rpc-whitelist": "127.0.0.1,192.168.*.*,172.*.*.*,10.*.*.*",
"rpc-authentication-required": true,
EOF
else
  echo "WARNING: Invalid value for TRANSMISSION_RPC_PORT: ${TRANSMISSION_RPC_PORT}" 1>&2
  exit 1
fi

echo '"alt-speed-enabled": false,' >>"$TRANSMISSION_SETTINGS"
if [ "${TRANSMISSION_UP_SPEED:-0}" -gt 0 ]; then
  echo "\"speed-limit-up\": ${TRANSMISSION_UP_SPEED}," >>"$TRANSMISSION_SETTINGS"
  echo '"speed-limit-up-enabled": true,' >>"$TRANSMISSION_SETTINGS"
else
  echo '"speed-limit-up": 1000000,' >>"$TRANSMISSION_SETTINGS"
  echo '"speed-limit-up-enabled": false,' >>"$TRANSMISSION_SETTINGS"
fi
if [ "${TRANSMISSION_DOWN_SPEED:-0}" -gt 0 ]; then
  echo "\"speed-limit-down\": ${TRANSMISSION_DOWN_SPEED}," >>"$TRANSMISSION_SETTINGS"
  echo '"speed-limit-down-enabled": true,' >>"$TRANSMISSION_SETTINGS"
else
  echo '"speed-limit-down": 1000000,' >>"$TRANSMISSION_SETTINGS"
  echo '"speed-limit-down-enabled": false,' >>"$TRANSMISSION_SETTINGS"
fi

if [ "${TRANSMISSION_QUEUE:-0}" -eq 1 ]; then
  cat <<EOF >>"$TRANSMISSION_SETTINGS"
"seed-queue-enabled": true,
"queue-stalled-enabled": true,
"download-queue-enabled": true,
EOF
else
  cat <<EOF >>"$TRANSMISSION_SETTINGS"
"seed-queue-enabled": false,
"queue-stalled-enabled": false,
"download-queue-enabled": false,
EOF
fi

### ANY NEW CONFIG MUST COME BEFORE THIS LINE ###

if [ -d "$TRANSMISSION_DOWNLOAD_DIR" ]; then
  echo "\"download-dir\": \"${TRANSMISSION_DOWNLOAD_DIR}\"" >>"$TRANSMISSION_SETTINGS"
else
  echo "ERROR: Ignoring invalid value for TRANSMISSION_DOWNLOAD_DIR: ${TRANSMISSION_DOWNLOAD_DIR}, must be an existing directory" 1>&2
  exit 1
fi

echo '}' >>"$TRANSMISSION_SETTINGS"

echo "Fix transmission's directories permissions"
for path in "$TRANSMISSION_CONF_DIR" "$TRANSMISSION_DOWNLOAD_DIR" "$TRANSMISSION_WATCH_DIR"; do
  if [ -d "$path" ]; then
    # this will cause less disk access than `chown -R`
    find "$path" \! -user transmission -exec chown transmission: '{}' +
  else
    chown transmission: "$path"
  fi
done

# Clear envvars after use
for _envvar in $(env | grep TRANSMISSION_ | awk -F= '{print $1}'); do
  if [ "$_envvar" != "TRANSMISSION_CONF_DIR" ] \
    && [ "$_envvar" != "TRANSMISSION_RPC_PORT" ] \
    && [ "$_envvar" != "TRANSMISSION_RPC_USER" ] \
    && [ "$_envvar" != "TRANSMISSION_RPC_PASSWORD" ]; then
    unset "$_envvar"
  fi
done

# Start transmission
su transmission -s /usr/bin/transmission-daemon -- -f -g "$TRANSMISSION_CONF_DIR" "${@}" &
_transmission_pid=$!
for _i in 1 2 3 6 9 14 15; do # signal fowarding (Only POSIX specified signals)
  if ! _signal="$(kill -l "$_i" 2>/dev/null)"; then
    echo "kill: invalid signal number or exit status: ${_i}" >&2
  else
    # shellcheck disable=SC2064
    trap "kill -s ${_signal} \$_transmission_pid 1>/dev/null 2>&1 || true" "$_signal"
  fi
done

# Wait till transmission is up
while ! rpc.sh session-stats; do
  sleep 1
done

if [ "$_blocklist" -eq 1 ]; then
  # Attempt first blocklist-update
  if rpc.sh blocklist-update; then
    # Start blocklist update loop
    (
      trap 'kill -s TERM $_transmission_pid' EXIT
      while true; do
        echo 'Next blocklist update will happen in a day'
        sleep 1d
        echo 'Updating blocklist...'
        if rpc.sh blocklist-update; then
          echo 'Blocklist updated'
        else
          echo 'Blocklist update failed'
          exit 1
        fi
      done
    ) &
    _blocklist_pid=$!
  else
    # First blocklist-update failed, kill transmission
    echo 'Blocklist update failed'
    kill -s TERM $_transmission_pid
  fi
fi

# Wait for transmission process
wait $_transmission_pid
if [ -n "${_blocklist_pid:-}" ]; then
  kill -s TERM "$_blocklist_pid" 1>/dev/null 2>&1 || true
fi
wait
