#!/usr/bin/env sh

# cSpell:ignore initful rshared ptmx

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
  echo "This container requires executing as root" 1>&2
  exit 1
fi

# Instantiate a new /dev/pts mount, this will ensure pseudoterminals are container-scoped
# and make easier in case of initful containers to have a separate /dev/console
mount --bind /dev/pts/ptmx /dev/ptmx

# Change mount propagation to shared to make the environment more similar to a
# modern Linux system, e.g. with Systemd as PID 1.
mount --make-rshared /

# Remove /dev/console when using init systems, this will confuse host system if
# we use rootful containers
# Instantiate a new pty to mount over /dev/console
# this way we will have init output right of the logs
[ -e /dev/console ] || touch /dev/console
rm -f /var/console
mkfifo /var/console
script -c "cat /var/console" /dev/null &

# Ensure the pty is created
sleep 0.5

# Mount the created pty over /dev/console in order to have systemd logs
# right into container logs
if ! mount --bind /dev/pts/0 /dev/console; then
  # Fallback to older behavior or fake plaintext file in case it fails
  # this ensures rootful + initful boxes do not interfere with host's /dev/console
  rm -f /var/console
  touch /var/console
  mount --bind /var/console /dev/console
fi

# Check if user given in arguments exists (if user is root, skip)
USER_NAME="${1:?}"
USER_ID="${2:?}"
GROUP_NAME="${3:?}"
GROUP_ID="${4:?}"
USER_HOME="${5:?}"
if [ -n "${USER_NAME}" ] \
  && [ -n "${USER_ID}" ] \
  && [ -n "${GROUP_NAME}" ] \
  && [ -n "${GROUP_ID}" ] \
  && [ -n "${USER_HOME}" ] \
  && [ "${USER_ID}" -ne 0 ]; then
  # Create group if it does not exist
  if ! getent group "${GROUP_NAME}" >/dev/null 2>&1; then
    addgroup -g "${GROUP_ID}" "${GROUP_NAME}"
  fi

  # Ensure home directory exists
  if [ ! -d "${USER_HOME}" ]; then
    mkdir -p "${USER_HOME}"
  fi

  # Create user if it does not exist
  if ! getent passwd "${USER_NAME}" >/dev/null 2>&1; then
    adduser -u "${USER_ID}" -D -G "${GROUP_NAME}" -H -h "${USER_HOME}" -s /bin/bash "${USER_NAME}"
  fi

  # Ensure home directory has proper ownership
  chown "${USER_ID}:${GROUP_ID}" "${USER_HOME}"
fi

# Fallback to standard init path, this is useful in case of non-Systemd containers
# like an openrc alpine
exec /sbin/init
