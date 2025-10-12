#!/bin/bash

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

# Converts an IPv4 netmask from dot-decimal notation (e.g., 255.255.255.0) to CIDR prefix length (e.g., /24).
mask_to_cidr() {
  local mask=$1
  local cidr=0
  local in_zeros=false

  # Validate input format.
  if ! [[ "$mask" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Invalid mask format for '$mask'." >&2
    return 1
  fi

  # Split into octets using IFS.
  IFS='.' read -r -a octets <<<"$mask"

  # Process each octet.
  for octet in "${octets[@]}"; do
    # Validate octet range.
    if ((octet < 0 || octet > 255)); then
      echo "Error: Invalid octet value '$octet' in mask '$mask'." >&2
      return 1
    fi

    # Check bits from Most Significant Bit to Least Significant Bit.
    for i in {7..0}; do
      bit_value=$((1 << i))
      if (((octet & bit_value) != 0)); then
        # If we already found a zero, finding a one later means the mask is invalid
        # because the bits are not contiguous.
        if $in_zeros; then
          echo "Error: Invalid netmask '$mask' - discontinuous bits." >&2
          return 1
        fi
        ((cidr++))
      else
        in_zeros=true
      fi
    done
  done

  echo "$cidr"
}

# --- Validation ---

has ip

# --- Main ---

eval "$(
  cat /proc/cmdline | tr ' ' '\n' | grep '^ip=' | cut -c4- \
    | awk -F: '{ printf "IP=%s;GATEWAY=%s;MASK=%s;HOSTNAME=%s;DEVICE=%s;DNS=%s",$1,$3,$4,$5,$6,$8 }'
)"

IP="${IP:?}"
MASK="$(mask_to_cidr "${MASK:?}")"
DEVICE="${DEVICE:?}"
GATEWAY="${GATEWAY:?}"
NETWORK="${GATEWAY%.*}.0"

echo "${HOSTNAME:?}" >/etc/hostname
echo "nameserver ${DNS:?}" >/etc/resolv.conf
ip link set "$DEVICE" down
ip addr flush dev "$DEVICE"
ip addr add "${IP}/${MASK}" dev "$DEVICE"
ip link set "$DEVICE" up
ip route add default via "$GATEWAY" dev "$DEVICE"
ip route add "${NETWORK}/${MASK}" via "$IP" 2>/dev/null || true
ip route add "${NETWORK}/${MASK}" dev "$DEVICE" 2>/dev/null || true

if [ "$(curl -o /dev/null -s -w "%{http_code}" "http://google.com/generate_204")" -eq 204 ]; then
  echo "Network configured successfully"
else
  echo "Error: Network configuration failed" >&2
  exit 1
fi
