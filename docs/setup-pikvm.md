# Setup PiKVM

> Assuming PiKVM DIY v2 deployed on a Raspberry Pi 4 4GB with an ATX board and HDMI-CSI bridge

## Flash aarch64 PiKVM OS image

https://docs.pikvm.org/flashing_os

## After first boot

1. Login as root

1. Enable read/write

   ```sh
   $> rw
   ```

1. Configure network

   ```sh
   $> cat << EOF > /etc/systemd/network/eth0.network
   [Match]
   Name=eth0

   [Network]
   Address=${IPADDR:?}/23
   DNS=${DNS:?}
   DNSSEC=no
   IPv6AcceptRA=yes
   LinkLocalAddressing=yes
   DHCPPrefixDelegation=no
   IPv6LinkLocalAddressGenerationMode=eui64

   [Route]
   Gateway=${GATEWAY:?}
   # https://github.com/pikvm/pikvm/issues/583
   Metric=10

   [DHCP4]
   Use6RD=no

   [DHCPV6]
   UseDelegatedPrefix=no

   [DHCPv6PrefixDelegation]
   Assign=no
   Announce=no
   ```

1. Configure hostname

   ```sh
   $> hostnamectl hostname ${HOSTNAME:?}
   ```

1. Configure ssh

   - Copy [`sshd.conf`](butane/etc/sshd.conf) to `/etc/ssh/sshd_config.d/99-custom.conf`

   - Add specific settings for PiKVM

     ```sh
     $> cat << EOF > /etc/ssh/sshd_config.d/00-pikvm.conf
     PermitRootLogin yes
     Subsystem sftp /usr/lib/ssh/sftp-server -f AUTHPRIV -l INFO
     EOF
     ```

   - Add ssh keys

     ```sh
     $> cat << EOF > /root/.ssh/authorized_keys
     sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBMXynyIuGR1frHPTMDg5DBIKKSaO1Wut7iytA9s6RTz5haEKhQSw42lSdJcUnDdPNSYQ47zqYxGrg0l7FXyiS4wAAAAEc3NoOg== ShadowValley-12-12-2021-physical_solokey_0
     ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBp3qXL7OmnuoELorBE0p2vgGIf2LwrGABr+PGmo9JdfM6leBWo9eJ7UUInXpSsKuIh3Cug2kkPqIcUsBMaE/pc= macbook-pro-touchid@secretive.vitor’s-MacBook-Pro.local
     EOF

     ```

   - Test ssh

1. Configure KVM password and 2FA

   ```sh
   $> kvmd-htpasswd set admin
   $> kvmd-totp init
   ```

1. Configure web terminal

   - Enable sudo for `kvmd-webterm`

     ```sh
     $> passwd kvmd-webterm
     $> systemd-sysusers /usr/lib/sysusers.d/kvmd-webterm.conf
     $> cat << EOF > /etc/sudoers.d/10_kvmd_webterm
     kvmd-webterm ALL=(ALL:ALL) ALL
     EOF
     ```

   - Login as `kvmd-webterm` and test sudo

   - Disable root login

     ```ssh
     $> sudo passwd -dl root
     ```

1. Install dependencies

   - Install `paru`

     ```sh
     $> curl -L# 'https://github.com/Morganamilo/paru/releases/download/v2.1.0/paru-v2.1.0-aarch64.tar.zst' | tar -xf- --zstd 'paru'
     $> paru -S --needed paru-bin
     $> rm paru
     ```

   - Install rank-mirrors

     ```sh
     $> paru -S --needed rate-mirrors-bin
     ```

1. Configure mirror list

   ```sh
   $> sudo rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist archarm
   ```

1. Update PiKVM

   ```sh
   $> sudo pikvm-update
   ```

1. Use `nftables` instead of `iptables`:

   ```sh
   $> paru -S --needed iptables-nft
   ```

1. Configure Tailscale:

  - Enable firewall mode:

   ```sh
   $> cat << EOF | sudo tee -a /etc/default/tailscaled

   # Enable firewall mode
   TS_DEBUG_FIREWALL_MODE="nftables"
   EOF
   ```

   - Start Tailscale service and login:

   ```sh
   $> sudo systemctl enable --now tailscaled
   $> sudo tailscale login
   ```

1. Reboot
