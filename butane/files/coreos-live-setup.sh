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
    return 1
  fi
}

# --- Validation ---

has curl
has jq

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if [ $# -ne 1 ] || [ -z "${1}" ]; then
  echo "Usage: $0 <IGNITION_URL>" 1>&2
  exit 1
fi

mapfile -t GRUB_CFGS < <(
  find /boot -type f -name 'grub.cfg' |
    awk '{print length, $0}' | sort -n -s | cut -d" " -f2-
)
GRUB_DIR="$(dirname "${GRUB_CFGS[0]:-/boot/grub/grub.cfg}")"
if ! [ -d "$GRUB_DIR" ]; then
  echo "Error: Could not find GRUB directory" 1>&2
  exit 1
fi

IGNITION_URL="$1"
if ! IGNITION_VERSION="$(curl -fsSL "$IGNITION_URL" | jq -r '.ignition.version')" ||
  ! [[ "$IGNITION_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "Error: Invalid Ignition URL" 1>&2
  exit 1
fi

GRUB_REBOOT='grub-reboot'
if ! has "$GRUB_REBOOT" 2>/dev/null; then
  GRUB_REBOOT='grub2-reboot'
  if ! has "$GRUB_REBOOT" 2>/dev/null; then
    GRUB_REBOOT=''
  fi
fi

# --- Main ---

echo "Ignition config version: $IGNITION_VERSION"

# Check if /boot is mounted read-only
if mount | awk '$3 == "/boot" {print $6}' | grep -q 'ro,'; then
  # Remount /boot as read-write
  mount -o remount,rw /boot
  trap 'mount -o remount,ro /boot' EXIT
fi

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
DNS="208.67.222.222" # OpenDNS
mapfile -t ROUTE < <(
  ip --json route list |
    jq -r '.[] | select(.dst == "default") | "\(.dev)\n\(.gateway)"'
)
IP_ADDR="$(
  ip --json addr show "${ROUTE[0]}" |
    jq -r '.[0] | .addr_info[] | select(.family == "inet") | .local'
)"
HOSTNAME="$(cat /etc/hostname)"

# Check if the default route interface is a bridge
if [ -d "/sys/class/net/${ROUTE[0]}/bridge" ]; then
  # Find all non-bridge, non-virtual interfaces
  interfaces=()
  for iface_path in $(ip --json addr show | jq -r '.[] | .ifname'); do
    iface=$(basename "$iface_path")
    # Skip loopback, bridges, and virtual interfaces
    if [ "$iface" = "lo" ] ||
      [ -d "/sys/class/net/${iface_path}/bridge" ] ||
      [[ "$(readlink -f "/sys/class/net/${iface_path}/device" 2>/dev/null)" == *"/virtual/"* ]]; then
      continue
    fi
    interfaces+=("$iface")
  done

  case "${#interfaces[@]}" in
    0)
      echo "Error: No suitable physical network interfaces found." >&2
      exit 1
      ;;
    1) selected_iface="${interfaces[0]}" ;;
    *)
      echo "Warning: Default route interface '${ROUTE[0]}' is a bridge." >&2
      echo "A physical interface is required for the installation." >&2
      echo "Please select a network interface to use:"
      PS3="Select interface: "
      selected_iface=""
      select iface in "${interfaces[@]}"; do
        if [[ -n "$iface" ]]; then
          selected_iface="$iface"
          break
        else
          echo "Invalid selection. Please try again." >&2
        fi
      done
      ;;
  esac

  if [[ -z "$selected_iface" ]]; then
    echo "Error: No interface selected. Aborting." >&2
    exit 1
  fi

  master="$(ip --json addr show "$selected_iface" | jq -r '.[0] | .master')"
  if [ "$master" != "${ROUTE[0]}" ]; then
    if [ -n "$master" ] && [ "$master" != "null" ]; then
      : # If the selected interface is enslaved to a different bridge, get the bridge IP
    else
      # If the selected interface is not enslaved, get its own IP
      master="$selected_iface"
    fi

    # Re-calculate IP_ADDR for the selected interface
    IP_ADDR="$(
      ip --json addr show "${master}" |
        jq -r '.[0] | .addr_info[] | select(.family == "inet") | .local'
    )"
    if [ -z "$IP_ADDR" ]; then
      echo "Error: Could not determine IPv4 address for interface '${ROUTE[0]}'." >&2
      exit 1
    fi
  fi

  ROUTE[0]="$selected_iface"
fi

echo "Downloading Fedora CoreOS version ${VERSION} for architecture ${ARCH}"

# Download the kernel
curl -f#L -o "/boot/fcos/fedora-coreos-${VERSION}-live-kernel.${ARCH}" \
  "${BASEURL}/${VERSION}/${ARCH}/fedora-coreos-${VERSION}-live-kernel.${ARCH}"

# Download the initramfs
curl -f#L -o "/boot/fcos/fedora-coreos-${VERSION}-live-initramfs.${ARCH}.img" \
  "${BASEURL}/${VERSION}/${ARCH}/fedora-coreos-${VERSION}-live-initramfs.${ARCH}.img"

echo "Configuring GRUB2 to boot Fedora CoreOS Live installer"

cat <<EOF >"${GRUB_DIR}/custom.cfg"
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

if ! { mount | grep -q '/boot'; }; then
  if has proxmox-boot-tool 2>/dev/null; then
    echo "WARNING: Proxmox requires extra manual steps to update GRUB2 configuration" >&2
  fi
  echo "${GRUB_DIR} is NOT the real grub boot directory!" >&2
  echo "Mount the real boot to /mnt/boot and run:" >&2
  echo "$> cp ${GRUB_DIR}/custom.cfg /mnt/boot/grub/custom.cfg" >&2
  echo "$> cp -r /boot/fcos /mnt/boot/fcos" >&2

  # For Proxmox with a Raid1 ZFS root, these are the commands to run:
  # mkdir -p /mnt/boot{1,2}
  # mount /dev/nvme0n1p2 /mnt/boot1
  # mount /dev/nvme1n1p2 /mnt/boot2
  # cp /boot/grub/custom.cfg /mnt/boot1/grub/
  # cp /boot/grub/custom.cfg /mnt/boot2/grub/
  # cp -r /boot/fcos /mnt/boot1/
  # cp -r /boot/fcos /mnt/boot2/
elif [ -n "$GRUB_REBOOT" ]; then
  read -r -p "Do you want to reboot into Fedora CoreOS Live installer now? [y/N] " response
  if [[ "${response,,}" =~ ^y(es)?$ ]]; then
    "$GRUB_REBOOT" 'Fedora CoreOS (Live)'
    exec systemctl --force reboot
  fi
fi

echo
echo "You can reboot into Fedora CoreOS Live installer by running:"
echo "$> grub-reboot 'Fedora CoreOS (Live)'"
echo "$> systemctl --force reboot"
