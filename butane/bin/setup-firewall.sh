#!/usr/bin/env bash

# cSpell:ignore dhcpv6

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

has firewall-cmd

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# ---- Main Script ----

echo ">>> Resetting zones to a clean state..."

# Create the tailscale zone if it doesn't exist, otherwise do nothing.
firewall-cmd --permanent --new-zone=tailscale >/dev/null 2>&1 || true

# List all services/ports/rules in a zone and remove them one by one.
# This makes the script robustly idempotent.
for zone in FedoraServer tailscale; do
  # Reset Target to default before removing all rules
  firewall-cmd --permanent --zone="$zone" --set-target=default

  # Remove all services
  for service in $(firewall-cmd --permanent --zone="$zone" --list-services); do
    firewall-cmd --permanent --zone="$zone" --remove-service="$service"
  done
  # Remove all ports
  for port in $(firewall-cmd --permanent --zone="$zone" --list-ports); do
    firewall-cmd --permanent --zone="$zone" --remove-port="$port"
  done
  # Remove all rich rules
  for rule in $(firewall-cmd --permanent --zone="$zone" --list-rich-rules); do
    firewall-cmd --permanent --zone="$zone" --remove-rich-rule="$rule"
  done
done

echo ">>> Configuring the public zone (FedoraServer)..."

# Set the default target to DROP for a default-deny policy.
firewall-cmd --permanent --zone=FedoraServer --set-target=DROP

# Allow specific services
firewall-cmd --permanent --zone=FedoraServer --add-service=http
firewall-cmd --permanent --zone=FedoraServer --add-service=https
firewall-cmd --permanent --zone=FedoraServer --add-service=dhcpv6-client

# Allow Tailscale ports.
firewall-cmd --permanent --zone=FedoraServer --add-port=41641/udp

# Allow all ICMP traffic.
firewall-cmd --permanent --zone=FedoraServer --add-rich-rule='rule protocol value="icmp" accept'
firewall-cmd --permanent --zone=FedoraServer --add-rich-rule='rule protocol value="ipv6-icmp" accept'

echo ">>> Configuring the dedicated Tailscale zone..."

# Assign the tailscale0 interface to this zone.
firewall-cmd --permanent --zone=tailscale --change-interface=tailscale0

# Set the default target to DROP for a default-deny policy.
firewall-cmd --permanent --zone=tailscale --set-target=DROP

# Allow specific services.
firewall-cmd --permanent --zone=tailscale --add-service=dns
firewall-cmd --permanent --zone=tailscale --add-service=ssh
firewall-cmd --permanent --zone=tailscale --add-service=http
firewall-cmd --permanent --zone=tailscale --add-service=https
firewall-cmd --permanent --zone=tailscale --add-service=glusterfs

# Allow some common http alternative ports.
firewall-cmd --permanent --zone=tailscale --add-port=8000/tcp
firewall-cmd --permanent --zone=tailscale --add-port=8080/tcp

# Allow Docker Swarm ports.
firewall-cmd --permanent --zone=tailscale --add-port=2377/tcp # Cluster management
firewall-cmd --permanent --zone=tailscale --add-port=7946/tcp # Node communication
firewall-cmd --permanent --zone=tailscale --add-port=7946/udp # Node communication
firewall-cmd --permanent --zone=tailscale --add-port=4789/udp # Overlay network

# Allow all ICMP traffic.
firewall-cmd --permanent --zone=tailscale --add-rich-rule='rule protocol value="icmp" accept'
firewall-cmd --permanent --zone=tailscale --add-rich-rule='rule protocol value="ipv6-icmp" accept'

echo ">>> Applying firewall rules..."

# Reload firewalld to apply the permanent configuration
firewall-cmd --reload

echo "Firewall configuration applied successfully!"
echo ""
echo "--- Final Configuration ---"
echo "--- Public Zone (FedoraServer) ---"
firewall-cmd --zone=FedoraServer --list-all
echo ""
echo "--- Tailscale Zone ---"
firewall-cmd --zone=tailscale --list-all
