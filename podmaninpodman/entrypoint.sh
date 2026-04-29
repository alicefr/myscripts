#!/bin/bash
SOCKET_DIR=/run/podman
SOCKET_PATH="${SOCKET_DIR}/podman.sock"
mkdir -p "${SOCKET_DIR}"
podman system service --time 0 --log-level=debug "unix://${SOCKET_PATH}"
