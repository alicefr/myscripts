#!/bin/bash

mkdir -p /run/podman

PODMAN_SOCK=/run/podman/podman.sock
podman --remote=false system service --time=0 "unix://${PODMAN_SOCK}" &

timeout=10
while [ ! -S "$PODMAN_SOCK" ] && [ $timeout -gt 0 ]; do
	sleep 0.5
	timeout=$((timeout - 1))
done

export CONTAINER_HOST="unix://${PODMAN_SOCK}"
exec claude "$@"
