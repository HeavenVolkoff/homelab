#!/usr/bin/env bash

set -euo pipefail

# --- Function ---

has() {
  if [ $# -ne 1 ]; then
    echo "Usage: has <command>" >&2
    exit 1
  fi

  if ! command -v "$1" &>/dev/null; then
    echo "Error: Dependency '$1' is not installed. Please install it to continue." >&2
    exit 1
  fi
}

# --- Validation ---

has curl
has jq
has coreos-installer

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Default route information
DNS="208.67.222.222"
mapfile -t ROUTE < <(
  ip --json route list |
    jq -r '.[] | select(.dst == "default") | "\(.dev)\n\(.gateway)"'
)
IP_ADDR="$(
  ip --json addr show "${ROUTE[0]}" |
    jq -r '.[0] | .addr_info[] | select(.family == "inet") | .local'
)"
HOSTNAME="$(cat /etc/hostname)"

# Retrieve Ignition URL from kernel command line
if [ -z "${IGNITION_URL:-}" ]; then
  IGNITION_URL="$(cat /proc/cmdline | tr ' ' '\n' | awk -F= '$1 == "ignition.config.url" {print $2}')"
fi

if ! [[ "$IGNITION_URL" =~ ^https?://.+/[^/]+$ ]]; then
  echo "Error: Invalid Ignition URL" 1>&2
  exit 1
fi

# Change ignition URL to point to host-specific config
IGNITION_URL="${IGNITION_URL%/*}/${HOSTNAME}.ign"

# Validate Ignition URL and fetch version
if ! IGNITION_VERSION="$(curl -fsSL "$IGNITION_URL" | jq -r '.ignition.version')" ||
  ! [[ "$IGNITION_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "Error: Invalid Ignition URL" 1>&2
  exit 1
fi

echo "Ignition config version: $IGNITION_VERSION"

# Get list of disks to present to the user
mapfile -t DISK_OPTIONS < <(
  lsblk -d -p -o NAME,SIZE,MODEL --json |
    jq -r '.blockdevices[] | select(.name | test("/zram|/loop|/sr") | not) | "\(.name) (\(.size) \(.model // ""))"'
)

if [ "${#DISK_OPTIONS[@]}" -eq 0 ]; then
  echo "Error: No disks found to install Fedora CoreOS" 1>&2
  exit 1
fi

echo "Please select the target disk for installation:"
echo "WARNING: All data on the selected disk will be lost!"
PS3="Enter the number of the target disk: "
select OPTION in "${DISK_OPTIONS[@]}"; do
  if [[ -n "$OPTION" ]]; then
    # Extract the disk name (e.g., /dev/sda) from the selected string
    TARGET_DISK=$(echo "$OPTION" | awk '{print $1}')
    # Look for a stable path in /dev/disk/by-id
    mapfile -t ID_PATHS < <(
      find /dev/disk/by-id -type l -exec readlink -nf {} ';' -exec echo " {}" ';' |
        awk "\$1 == \"${TARGET_DISK}\" {print \$2}" |
        awk -F- '$2 ~ /^id\/(ata|nvme|scsi)$/ {print length, $0}' |
        sort -n -s | cut -d" " -f2-
    )
    if [ "${#ID_PATHS[@]}" -gt 0 ]; then
      read -r -p "Using stable disk path ${ID_PATHS[0]} (Y/n)? " CONFIRM
      if [[ "${CONFIRM:-Y}" =~ ^[Yy]$ ]]; then
        TARGET_DISK="${ID_PATHS[0]}"
      fi
    fi
    break
  else
    echo "Invalid selection. Please try again."
  fi
done

exec coreos-installer install -s stable -p metal \
  --append-karg "ip=${IP_ADDR}::${ROUTE[1]}:255.255.255.0:${HOSTNAME}:${ROUTE[0]}:none:${DNS}" \
  --ignition-url "${IGNITION_URL}" \
  "$TARGET_DISK"
