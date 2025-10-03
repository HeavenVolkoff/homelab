# [Butane](https://coreos.github.io/butane) configuration for [CoreOS](https://fedoraproject.org/coreos/)

In this directory are the files required to build a couple of
[butane](https://coreos.github.io/butane) configuration files for the deployment
of [ucore](https://github.com/HeavenVolkoff/ucore) for the hosts that compose my
homelab.

## Build

The butane spec does not support spliting configuration files. So, a build step
is required to transpile all the files into a set of butane files that will then
be compiled into ignition files to be used during the CoreOS installation.

```sh
$> ./build.sh
```

The Ignition files will be written to `./output/*.ign`
