#!/bin/bash

export CLOUDSDK_CONFIG=~/.config/gcloud.claude
IMAGE=opencode

build () {
	cd $HOME/src/myscripts/opencode/images && podman build -t $IMAGE .
}

config () {
	gcloud init
	gcloud auth application-default login
	gcloud auth application-default set-quota-project cloudability-it-gemini
}

usage () {
	echo "Usage: $(basename $0) [-s SESSION_NAME] [-r] [-m HOST_PATH] [build|config]"
	echo "  -s SESSION_NAME  start a new named session"
	echo "  -r               resume (optionally with -s to pick a specific session)"
	echo "  -m HOST_PATH     mount HOST_PATH into /workspace/<basename of HOST_PATH>"
}

while getopts "s:rm:" opt; do
	case "$opt" in
		s) SESSION_NAME="$OPTARG" ;;
		r) RESUME=1 ;;
		m) EXTRA_MOUNT="$OPTARG" ;;
		*) usage; exit 1 ;;
	esac
done
shift $((OPTIND - 1))

case "$1" in
	"build")
	    build
	    exit
	;;
	"config")
	    config
	    exit
	;;
esac

if [[ -z "${SESSION_NAME}" && -z "${RESUME}" ]]; then
	echo "Error: either -s SESSION_NAME or -r is required"
	usage
	exit 1
fi

if [[ "${PWD}" == "${HOME}" ]]; then
	echo "You should not use opencode on your home directory"
	usage
	exit 1
fi

CONTAINER_NAME="${SESSION_NAME:-opencode-resume}"
# --session creates the session if it does not exist yet; IDs must start with "ses"
OPENCODE_ARGS="--auto --standalone"
if [[ -n "${SESSION_NAME}" ]]; then
	OPENCODE_ARGS="${OPENCODE_ARGS} --session ses_${SESSION_NAME}"
else
	OPENCODE_ARGS="${OPENCODE_ARGS} --continue"
fi

if ! podman ps --format '{{.Names}}' | grep -q '^podman-remote-cont$'; then
	echo "Error: podman-remote-cont is not running. Start it with: run-podman.sh"
	exit 1
fi

EXTRA_MOUNT_ARGS=""
if [[ -n "${EXTRA_MOUNT}" ]]; then
	EXTRA_MOUNT_NAME=$(basename "${EXTRA_MOUNT}")
	ln -sf "/mnt/${EXTRA_MOUNT_NAME}" "${PWD}/${EXTRA_MOUNT_NAME}"
	trap "rm -f '${PWD}/${EXTRA_MOUNT_NAME}'" EXIT
	EXTRA_MOUNT_ARGS="-v ${EXTRA_MOUNT}:/mnt/${EXTRA_MOUNT_NAME}"
fi

# Persist user config, session data and state on the host, separate from
# any opencode installed directly on the host
mkdir -p ~/.config/opencode-enmaas/opencode ~/.local/share/opencode-enmaas ~/.local/state/opencode-enmaas

podman run -it --rm \
	--name "${CONTAINER_NAME}" \
	--env HOME="${HOME}" \
	--tmpfs "${HOME}" \
	--env ENMAAS_KEY="$ENMAAS_KEY" \
	-e GH_TOKEN=$GH_TOKEN_READER \
	-e COLORTERM=truecolor \
	-e CONTAINER_HOST=unix:///run/podman/podman.sock \
	-v podman-socket:/run/podman \
	--network=container:podman-remote-cont \
	--security-opt label=disable \
	-v ~/.config/opencode-enmaas/opencode:${HOME}/.config/opencode \
	-v ~/.local/share/opencode-enmaas:${HOME}/.local/share/opencode \
	-v ~/.local/state/opencode-enmaas:${HOME}/.local/state/opencode \
	-v ~/.config/gcloud.claude:${HOME}/.config/gcloud:ro \
	-v ~/.agents/skills:${HOME}/.agents/skills \
	-v ~/.agents/skills:${HOME}/.config/opencode/skills:ro \
	-v ~/.claude/commands:${HOME}/.config/opencode/commands:ro \
	-v ~/.claude/commands:${HOME}/.config/opencode/command:ro \
	-v ~/.claude/scripts:${HOME}/.claude/scripts:ro \
	-v ${PWD}:/workspace \
	${EXTRA_MOUNT_ARGS} \
	-w /workspace \
	--userns=keep-id \
	--group-add keep-groups \
	--user $(id -u):$(id -g) \
	-v /run/user/$(id -u)/bus:/run/user/$(id -u)/bus:ro \
	-e DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus \
	--entrypoint opencode \
	$IMAGE ${OPENCODE_ARGS}
