# Setup Glusterfs

> The tutorial assumes you using a Ubuntu system

## Configure a Disk for GlusterFS

### Partition and format:

```sh
sudo fdisk /dev/sdb
sudo mkfs.ext4 -L Storage /dev/sdb1
```

### Create mountpoint:

```sh
sudo mkdir /glusterfs
```

### Create `glusterfs.mount`:

Create file `/etc/systemd/system/glusterfs.mount`:

```
[Unit]
Description=GlusterFS brick storage Mount

[Mount]
Where=/glusterfs
What=/dev/disk/by-label/Storage
Type=ext4
Options=defaults,relatime,lazytime,_netdev,nofail
```

Enable mount `sudo systemctl enable --now glusterfs.mount`

## Install GlusterFS (Only for x86)

```sh
sudo apt install software-properties-common
sudo add-apt-repository ppa:gluster/glusterfs-10
sudo apt install glusterfs-server
```

### Build from source:

> **WARNING:**
>
> glusterfs > 7 is not available pre-built for Ubuntu ARM64.

- Generate a gpg key with RSA 4096bits.

  User: GlusterFS GlusterFS deb packages
  Email: deb.packages@gluster.org

  ```sh
  gpg --full-generate-key
  ```

- Generate deb package

  ```sh
  cd
  mkdir -p ~/Workspace/build
  cd ~/Workspace

  git clone --depth 1 --branch focal-glusterfs-10 https://github.com/gluster/glusterfs-debian.git
  git clone --depth 1 --branch v10.1 https://github.com/gluster/glusterfs.git
  cd glusterfs
  cp -r ../glusterfs-debian/debian ./
  cp -r /opt/DockerHills/scritps/make-debs.sh ./

  ./make-debs.sh ~/Workspace/build
  ```

### Edit `glusterd.service`:

Execute `sudo systemctl edit --full glusterd.service` and replace content with:

```
[Unit]
Description=GlusterFS, a clustered file-system server
Documentation=man:glusterd(8)
StartLimitBurst=6
StartLimitIntervalSec=3600
RequiresMountsFor=/glusterfs

[Service]
Type=forking
PIDFile=/var/run/glusterd.pid
LimitNOFILE=65536
Environment="LOG_LEVEL=INFO"
EnvironmentFile=-/etc/sysconfig/glusterd
ExecStart=/usr/sbin/glusterd -p /var/run/glusterd.pid  --log-level $LOG_LEVEL $GLUSTERD_OPTIONS
ExecStartPost=/usr/local/sbin/glusterfs-wait
KillMode=process
TimeoutSec=300
SuccessExitStatus=15
Restart=on-abnormal
RestartSec=60
StartLimitBurst=6
StartLimitInterval=3600

[Install]
WantedBy=multi-user.target
```

## Enable GlusterFS service

```sh
sudo systemctl enable --now glusterd.service
sudo systemctl status glusterd.service
```

## Edit /etc/hosts

Add a DNS names for all machines that will be part of the GlusterFS cluster
This tutorial will assume 3 machines with names: gluster0 gluster1 gluster2

## Add peers

### On machine gluster0, execute:

```sh
sudo gluster peer probe gluster1
sudo gluster peer probe gluster2
```

### Check peers status:

```sh
sudo gluster peer status
```

## Create GlusterFS volume

```sh
sudo gluster volume create storage replica 3 gluster0:/glusterfs gluster1:/glusterfs gluster2:/glusterfs force
```

### Configure volume:

- https://docs.gluster.org/en/latest/Administrator-Guide/Performance-Tuning/
- https://access.redhat.com/solutions/3673761
- https://serverfault.com/questions/823879#answer-909729
- https://serverfault.com/questions/402196#answer-608965
- https://lists.gluster.org/pipermail/gluster-users/2019-February/035852.html
- https://docs.openshift.com/container-platform/3.11/scaling_performance/optimizing_on_glusterfs_storage.html
- https://docs.gluster.org/en/latest/Administrator-Guide/Tuning-Volume-Options/
- https://github.com/gluster/glusterfs/issues/1113#issuecomment-757486248

```sh
sudo gluster volume set storage group nl-cache
sudo gluster volume set storage group metadata-cache
sudo gluster volume set storage cache-size 2GB
sudo gluster volume set storage nl-cache-positive-entry on
sudo gluster volume set storage cache-invalidation-timeout 600
sudo gluster volume set storage locks.mandatory-locking optimal
sudo gluster volume set storage server.event-threads 4
sudo gluster volume set storage server.allow-insecure on
sudo gluster volume set storage cluster.quorum-type auto
sudo gluster volume set storage cluster.use-anonymous-inode yes
sudo gluster volume set storage cluster.favorite-child-policy majority
sudo gluster volume set storage storage.owner-gid 1000
sudo gluster volume set storage storage.owner-uid 1000
sudo gluster volume set storage performance.io-cache off
sudo gluster volume set storage performance.quick-read off
sudo gluster volume set storage performance.read-ahead off
sudo gluster volume set storage performance.open-behind off
sudo gluster volume set storage performance.write-behind off
sudo gluster volume set storage performance.readdir-ahead off
sudo gluster volume set storage performance.stat-prefetch off
sudo gluster volume set storage performance.strict-o-direct on
sudo gluster volume set storage performance.parallel-readdir on
sudo gluster volume set storage performance.qr-cache-timeout 600
sudo gluster volume set storage performance.cache-max-file-size 2MB
```

## Start Volume

```sh
sudo gluster volume start storage
```

### Create a service for automounting glusterfs:

Following is an example for `/etc/systemd/system/opt-DockerHills-runtime.service`:

```
[Unit]
Description=DockerHills runtime GlusterFS Mount
StartLimitBurst=6
StartLimitIntervalSec=360
After=glusterd.service
Requires=glusterd.service
PartOf=glusterd.service

[Service]
Type=forking
PIDFile=/run/opt-DockerHills-runtime.pid
ExecStart=/usr/sbin/glusterfs -p /run/opt-DockerHills-runtime.pid --acl --capability --process-name fuse --volfile-server=localhost --volfile-id=/storage /opt/DockerHills/runtime
KillMode=process
SuccessExitStatus=15
TimeoutSec=300
Restart=on-failure
RestartSec=10
StartLimitBurst=6
StartLimitInterval=360

[Install]
WantedBy=multi-user.target
```

Then enable and start it:

```sh
sudo systemctl enable --now opt-DockerHills-runtime.service
```
