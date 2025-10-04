#!/usr/bin/env bash

mount -o remount,rw /boot

mkdir -p /boot/fcos

# Define variables for convenience
# GIST=""
ARCH="aarch64"
VERSION="42.20250914.3.0"
BASEURL="https://builds.coreos.fedoraproject.org/prod/streams/stable/builds"

# Download the kernel
curl -fsSL -o "/boot/fcos/fedora-coreos-${VERSION}-live-kernel.${ARCH}" \
    "${BASEURL}/${VERSION}/${ARCH}/fedora-coreos-${VERSION}-live-kernel.${ARCH}"

# Download the initramfs
curl -fsSL -o "/boot/fcos/fedora-coreos-${VERSION}-live-initramfs.${ARCH}.img" \
    "${BASEURL}/${VERSION}/${ARCH}/fedora-coreos-${VERSION}-live-initramfs.${ARCH}.img"

mkdir -p /boot/grub2

cat << EOF > /boot/grub2/user.cfg
menuentry 'Fedora CoreOS (Live)' {
    set arch="${ARCH}"
    set version="${VERSION}$"

    set dns="208.67.222.222"
    set mask="255.255.255.0"
    set ipaddr="10.0.0.102"
    set gateway="10.0.0.1"
    set hostname="oracle-nueve"
    set interface="enp0s6"

    set network="ip=\${ipaddr}::\${gateway}:\${mask}:\${hostname}:\${interface}:none:\${dns}"
    set baseurl="https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/\${version}/\${arch}"
    set configurl="${GIST:?Please set the GIST environment variable to your Ignition config URL}"

    echo "Loading Fedora CoreOS Kernel..."
    linux /fcos/fedora-coreos-\${version}-live-kernel.\${arch} initrd=main coreos.live.rootfs_url=\${baseurl}/fedora-coreos-\${version}-live-rootfs.\${arch}.img ignition.firstboot ignition.platform.id=metal ignition.config.url=\${configurl} \${network}

    echo "Loading Fedora CoreOS Initramfs..."
    initrd /fcos/fedora-coreos-\${version}-live-initramfs.\${arch}.img
}
EOF
