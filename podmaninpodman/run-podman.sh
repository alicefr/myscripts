#!/bin/bash

IMAGE=localhost/podinpod
podman run -td --rm --name podman-remote-cont \
	--privileged \
	--env HOME="${HOME}" \
	--env TERM="${TERM}" \
	-v ${PWD}:/workspace \
	-w /workspace \
	--device /dev/fuse \
	--device /dev/kvm \
	--device /dev/vhost-vsock \
	--device /dev/net/tun \
	-v container-var:/var/lib/containers \
	-v podman-var:/var/podman \
	-v podman-socket:/run/podman \
	$IMAGE
