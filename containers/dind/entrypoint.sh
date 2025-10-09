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
  # Fallback to older behaviour or fake plaintext file in case it fails
  # this ensures rootful + initful boxes do not interfere with host's /dev/console
  rm -f /var/console
  touch /var/console
  mount --bind /var/console /dev/console
fi

# Fallback to standard init path, this is useful in case of non-Systemd containers
# like an openrc alpine
exec /sbin/init
