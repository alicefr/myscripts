#!/bin/bash

IMAGE=localhost/podinpod
podman run -it --rm --name test-podman\
	-e CONTAINER_HOST=unix://run/podman/podman.sock \
	--entrypoint /bin/bash \
	--privileged \
	--env HOME="${HOME}" \
	--env TERM="${TERM}" \
	-v ${PWD}:/workspace \
	-w /workspace \
	-v podman-socket:/run/podman \
	$IMAGE
