#!/bin/sh

# cSpell:ignore gecos getent subuid tcmalloc tzdata userns

set -eu

# Enable testing repository for tcmalloc-minimal
echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >>/etc/apk/repositories

# Enable custom repositories for GlusterFS
wget -O /etc/apk/keys/ck-6787e0df.rsa.pub https://kohlschuetter.github.io/alpine-repo/keys/ck-6787e0df.rsa.pub
echo "https://kohlschuetter.github.io/alpine-repo" >>/etc/apk/repositories

# Install basic packages
apk add \
  bash \
  bash-completion \
  docker \
  docker-cli-compose \
  glusterfs \
  kitty-terminfo \
  lang \
  micro \
  nftables \
  openrc \
  tzdata \
  util-linux-misc

# Cleanup openrc to not interfere with the host
sed -i 's/^\(tty\d\:\:\)/#\1/g' /etc/inittab
sed -i \
  -e "/rc_cgroup_mode=/s/^#//g" \
  -e 's/#rc_env_allow=".*"/rc_env_allow="\*"/g' \
  -e 's/#rc_crashed_stop=.*/rc_crashed_stop=NO/g' \
  -e 's/#rc_crashed_start=.*/rc_crashed_start=YES/g' \
  -e 's/#rc_provide=".*"/rc_provide="loopback net"/g' \
  /etc/rc.conf

# Enable cgroups in openrc
rc-update add cgroups

# Configure docker remap group
getent group dockremap 2>/dev/null || addgroup --system dockremap
# Configure docker remap user
id -u dockremap 2>/dev/null \
  || adduser -SDH \
    --home /var/empty \
    --shell /sbin/nologin \
    --gecos "docker remap user" \
    --ingroup dockremap \
    dockremap

# Configure dockremap user and group ids
echo "dockremap:$(getent passwd dockremap | cut -d: -f3):65536" >/etc/subuid
echo "dockremap:$(getent group dockremap | cut -d: -f3):65536" >/etc/subgid

# Configure docker daemon
mkdir -p /etc/docker
{
  echo "{"
  echo "  \"mtu\": 1280,"
  echo "  \"ipv6\": true,"
  echo "  \"ip6tables\": true,"
  echo "  \"userland-proxy\": true,"
  echo "  \"userns-remap\": \"dockremap\""
  echo "}"
} >/etc/docker/daemon.json

# Create a no-op dev service, because other services depend on it
cat <<EOF >/etc/init.d/dev
#!/sbin/openrc-run
description="NOP service to ensure openrc works"
start() { : ; }
EOF

chmod +x /etc/init.d/dev

# Enable nftables in openrc
rc-update add nftables boot

# Enable syslog in openrc
rc-update add syslog boot

# Enable docker in openrc
rc-update add docker default
