#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if [ $# -ne 1 ] || [ -z "${1}" ]; then
  echo "Usage: $0 <IGNITION_URL>" 1>&2
  exit 1
fi

IGNITION_URL="$1"

if ! IGNITION_VERSION="$(curl -fsSL "$IGNITION_URL" | jq -r '.ignition.version')" ||
  ! [[ "$IGNITION_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "Error: Invalid Ignition URL" 1>&2
  exit 1
fi

echo "Ignition config version: $IGNITION_VERSION"

# Remount /boot as read-write
mount -o remount,rw /boot
trap 'mount -o remount,ro /boot' EXIT

# Create directory for Fedora CoreOS files
mkdir -p /boot/fcos

# Fetch latest Fedora CoreOS version and architecture
ARCH="$(uname -m)"
VERSION="$(
  curl -fsSL \
    'https://builds.coreos.fedoraproject.org/prod/streams/stable/releases.json' |
    jq -r '.releases[-1].version'
)"
BASEURL="https://builds.coreos.fedoraproject.org/prod/streams/stable/builds"

# Default route information
DNS="208.67.222.222"
mapfile -t ROUTE < <(ip --json route list | jq -r '.[] | select(.dst == "default") | "\(.dev)\n\(.gateway)"')
IP_ADDR="$(ip --json addr show "${ROUTE[0]}" | jq -r '.[0] | .addr_info[] | select(.family == "inet") | .local')"
HOSTNAME="$(cat /etc/hostname)"

echo "Downloading Fedora CoreOS version ${VERSION} for architecture ${ARCH}"

# Download the kernel
curl -fsSL -o "/boot/fcos/fedora-coreos-${VERSION}-live-kernel.${ARCH}" \
  "${BASEURL}/${VERSION}/${ARCH}/fedora-coreos-${VERSION}-live-kernel.${ARCH}"

# Download the initramfs
curl -fsSL -o "/boot/fcos/fedora-coreos-${VERSION}-live-initramfs.${ARCH}.img" \
  "${BASEURL}/${VERSION}/${ARCH}/fedora-coreos-${VERSION}-live-initramfs.${ARCH}.img"

echo "Configuring GRUB2 to boot Fedora CoreOS Live installer"
mkdir -p /boot/grub2
cat <<EOF >/boot/grub2/custom.cfg
menuentry 'Fedora CoreOS (Live)' {
    set arch="${ARCH}"
    set version="${VERSION}"

    set dns="$DNS"
    set mask="255.255.255.0"
    set ipaddr="$IP_ADDR"
    set gateway="${ROUTE[1]}"
    set hostname="$HOSTNAME"
    set interface="${ROUTE[0]}"

    set network="ip=\${ipaddr}::\${gateway}:\${mask}:\${hostname}:\${interface}:none:\${dns}"
    set baseurl="${BASEURL}/\${version}/\${arch}"
    set configurl="${IGNITION_URL}"

    echo "Loading Fedora CoreOS Kernel..."
    linux /fcos/fedora-coreos-\${version}-live-kernel.\${arch} initrd=main coreos.live.rootfs_url=\${baseurl}/fedora-coreos-\${version}-live-rootfs.\${arch}.img ignition.firstboot ignition.platform.id=metal ignition.config.url=\${configurl} \${network}

    echo "Loading Fedora CoreOS Initramfs..."
    initrd /fcos/fedora-coreos-\${version}-live-initramfs.\${arch}.img
}
EOF

# After boot
# sudo coreos-installer install -s stable -p metal \
#   --append-karg 'ip=${$IP_ADDR}::${ROUTE[1]}:255.255.255.0:${HOSTNAME}:${ROUTE[0]}:none:${DNS}' \
#   --ignition-url "${IGNITION_URL}" \
#   /dev/sda
