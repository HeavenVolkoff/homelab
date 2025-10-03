# Configuring Docker Swarm over WireGuard + IPv6

> The tutorial assumes a Linux distro with systemd environment

Links:

- [Ipv6 over WireGuard](https://www.reddit.com/r/WireGuard/comments/fuk0dd/ipv6_address_assignment_over_wireguard/)

Requirements:

- [jq](https://stedolan.github.io/jq/download/) is installed

- [uuidgen](https://github.com/karelzak/util-linux) is installed

- [Docker](https://docs.docker.com/engine/install/) is installed

- [libuuid](https://github.com/karelzak/util-linux) is installed

- Machine does NOT participate in a swarm

## Install and configure WireGuard

- [Official WireGuard install guide](https://www.wireguard.com/install/)

- [Arch's WireGuard tutorial](https://wiki.archlinux.org/index.php/WireGuard)

- [WireGuard's configuration example](../configs/wireguard/wg0.conf)

- Configure Docker to use the same MTU as the WireGuard interface

  > This is essential, because if the Docker interfaces ends up with an MTU larger
  > than what WireGuard uses, most request between containers will be dropped

  ```sh
  $> sh <<"EOF"
  set -eu
  touch /etc/docker/daemon.json
  _daemon_json="$(cat /etc/docker/daemon.json)"
  printf '%s' "${_daemon_json:-{\}}" |
    jq -S --arg mtu "$(
      ip addr | grep wg0 |
      grep -oP '(?<=mtu)\s+[1-9][0-9]*' |
      tr -d '[[:space:]]'
    )" '. | (.mtu|=($mtu|tonumber))' |
    tee /etc/docker/daemon.json

  EOF
  ```

## Configure IPv6 in Docker

- Enable IPv6 table Linux kernel module:

  Create file `/etc/modules-load.d/00-ipv6.conf` with the following content:

  ```sh
  $> echo 'ip6_tables' | tee /etc/modules-load.d/00-ipv6.conf
  ```

- Allow IPv6 forwarding:

  Create file `/etc/sysctl.d/00-ipv6.conf` with the following content:

  ```sh
  $> _if="$(ip -6 route | perl -wln -e '/default\s+via\s+[a-f0-9:]+\s+dev\s+\K[^\s]+/ and print $&' | sort -u | xargs -rn1 printf 'net.ipv6.conf.%s.accept_ra = 2\n')" && cat << EOF | tee /etc/sysctl.d/00-ipv6.conf

  net.ipv6.conf.all.forwarding = 1
  ${\_if}
  net.ipv6.conf.default.forwarding = 1
  EOF
  ```

- [Configure Docker to use ipv6](https://docs.docker.com/config/daemon/ipv6/):

  ```sh
  $> sh <<"EOF"
  set -eu
  touch /etc/docker/daemon.json
  _daemon_json="$(cat /etc/docker/daemon.json)"
  printf '%s' "${_daemon_json:-{\}}" |
    jq -S --arg ip "$(
      printf 'fd%s:%s:%s::/48' "$(uuidgen | cut -c 6-7)" "$(uuidgen | cut -c 10-13)" "$(uuidgen | cut -c 15-18)"
    )" '. | (.ipv6|=true) | (.ip6tables|=true) | (.["userland-proxy"]|=true) | (.["fixed-cidr-v6"]|=$ip)' |
    tee /etc/docker/daemon.json

  EOF
  ```

## Restart the Docker Daemon

```sh
$> systemctl restart docker
```

## Setup Docker Swarm

- Manually create the `docker_gwbridge` network to correctly configure IPv6 and MTU:

  ```sh
  $> sh <<"EOF"
  set -eu
  o4="$(shuf -i 0-256 -n1).$(( $(shuf -i 0-15 -n1) * 16 ))"
  o6="$(
    printf 'fd%s:%s:%s' "$(uuidgen | cut -c 6-7)" "$(uuidgen | cut -c 10-13)" "$(uuidgen | cut -c 15-18)"
  )"
  mtu="$(jq -r '.mtu' /etc/docker/daemon.json)"
  docker network create \
    --subnet "172.${o4}.0/20" \
    --gateway "172.${o4}.1" \
    --ipv6 \
    --subnet "${o6}::/64" \
    --gateway "${o6}::1" \
    --opt com.docker.network.driver.mtu="$mtu" \
    --opt com.docker.network.bridge.enable_icc=true \
    --opt com.docker.network.bridge.name=docker_gwbridge \
    --opt com.docker.network.bridge.enable_ip_forwarding=true \
    --opt com.docker.network.bridge.enable_ip_masquerade=true \
    docker_gwbridge
  EOF
  ```

- Initialize Swarm on manager node

  ```sh
  $> docker swarm init --advertise-addr wg0 --data-path-addr wg0 --listen-addr wg0
  ```

- Configure remaining nodes to join swarm

  ```sh
  $> docker swarm join --advertise-addr wg0 --data-path-addr wg0 --listen-addr wg0 --token <TOKEN> <ADDRESS>
  ```
