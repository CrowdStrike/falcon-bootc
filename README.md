# falcon-bootc

Configuration for creating a bootc-based image with the Falcon sensor installed.

This is an example that users should adapt to their bootc workflow. The resulting image will be
associated with a specific customer ID (CID). Upon startup, the host will generate a new agent ID (AID).

## Prerequisites

Only tested on ARM Macs so far.

1. Install Podman
2. Create a Podman machine with rootful and a volume mount:

```bash
podman machine init --rootful -v $HOME/projects:$HOME/projects
```

3. Log in to the Red Hat registry:

```bash
podman login registry.redhat.io
# enter your Red Hat login
```

4. Register the Podman machine so it has access to subscription content (don't copy and paste both commands into the terminal, you need to start the SSH session _then_ register):

```bash
podman machine ssh
# then inside the ssh session...
subscription-manager register
# enter your Red Hat login
```

## Building

1. Download a GPG key and RPM that matches the system's architecture and place them in `assets`. Note: the `Containerfile` installs any `*.gpg` and `*.rpm` file found, so ensure the files match this convention.
2. Retrieve your CID.
3. Build the container image: `podman build --build-arg FALCON_CID=$FALCON_CID -t falcon-bootc-demo:latest .`
4. Build the bootable image:

```
podman run \
  --rm \
  --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./config.toml:/config.toml \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  registry.redhat.io/rhel9/bootc-image-builder:latest \
  --type iso \
  --config /config.toml \
  --local=true \
  localhost/falcon-bootc-demo:latest
```

5. Launch a VM with the ISO as the boot disk.
