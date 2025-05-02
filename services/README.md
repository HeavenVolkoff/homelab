# Homelab deploy

## Requirements

For deploying you need to have [docker](https://docs.docker.com/engine/install/), [docker compose v2+](https://docs.docker.com/compose/install/) and [docker buildx](https://docs.docker.com/build/architecture/#install-buildx) installed

## Build custom images

To manually build a single service image run the following:

```sh
$> cd services/${SERVICE}
$> env BUILDX_EXPERIMENTAL=1 docker buildx debug --on=error build --build-context utilities=../../utilities --tag ghcr.io/heavenvolkoff/homelab/${SERVICE}:latest .
```

To build all services run the following from the root of the repository:

```sh
$> docker buildx bake --allow=network.host
```

## How to run

TODO

## Resources:

- Compose definition:
  > https://docs.docker.com/reference/compose-file

- List if all (?) docker swarm template placeholders:
  > https://forums.docker.com/t/example-usage-of-docker-swarm-template-placeholders/73859

  Compose environment:

  ```
  X_NODE_ID: '{{.Node.ID}}'
  X_NODE_HOSTNAME: '{{.Node.Hostname}}'
  X_NODE_PLATFROM: '{{.Node.Platform}}'
  X_NODE_PLATFROM_ARCHITECTURE: '{{.Node.Platform.Architecture}}'
  X_NODE_PLATFROM_OS: '{{.Node.Platform.OS}}'
  X_SERVICE_ID: '{{.Service.ID}}'
  X_SERVICE_NAMES: '{{.Service.Name}}'
  X_SERVICE_LABELS: '{{.Service.Labels}}'
  X_SERVICE_LABEL_STACK_NAMESPACE: '{{index .Service.Labels "com.docker.stack.namespace"}}'
  X_SERVICE_LABEL_STACK_IMAGE: '{{index .Service.Labels "com.docker.stack.image"}}'
  X_SERVICE_LABEL_CUSTOM: '{{index .Service.Labels "service.label"}}'
  X_TASK_ID: '{{.Task.ID}}'
  X_TASK_NAME: '{{.Task.Name}}'
  X_TASK_SLOT: '{{.Task.Slot}}'
  ```

  Resulting environment variables inside the container: (Stack is called `test`)

  ```
  X_NODE_HOSTNAME=docker2
  X_NODE_ID=o53jektysbnzxptwny1b7eurq
  X_NODE_PLATFROM='{x86_64 linux}'
  X_NODE_PLATFROM_ARCHITECTURE=x86_64
  X_NODE_PLATFROM_OS=linux
  X_SERVICE_ID=jjmbj2dxlfjopazfom07gv5gr
  X_SERVICE_LABELS='map[com.docker.stack.image:ubuntu:bionic com.docker.stack.namespace:test service.label:this is a label on the service]'
  X_SERVICE_LABEL_CUSTOM='this is a label on the service'
  X_SERVICE_LABEL_STACK_IMAGE=ubuntu:bionic
  X_SERVICE_LABEL_STACK_NAMESPACE=test
  X_SERVICE_NAMES=test_ubuntu
  X_TASK_ID=q5efpqrexn3h3zzoviy5o9wjc
  X_TASK_NAME=test_ubuntu.1.q5efpqrexn3h3zzoviy5o9wjc
  X_TASK_SLOT=1
  ```
