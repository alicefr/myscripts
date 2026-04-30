#!/bin/bash

export CLOUDSDK_CONFIG=~/.config/gcloud.claude
IMAGE=claude
STORAGE_DIR=$HOME/claude-containers

build () {
	cd $HOME/src/myscripts/claude/images && podman build -t $IMAGE .
}

config () {
	gcloud init
	gcloud auth application-default login
	gcloud auth application-default set-quota-project cloudability-it-gemini
}

usage () {
	echo "Usage: $(basename $0) [-s SESSION_NAME] [-r] [build|config]"
	echo "  -s SESSION_NAME  start a new named session"
	echo "  -r               resume (optionally with -s to pick a specific session)"
}

while getopts "s:r" opt; do
	case "$opt" in
		s) SESSION_NAME="$OPTARG" ;;
		r) RESUME=1 ;;
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
	echo "You should not use claude on your home directory"
	usage
	exit 1
fi

CONTAINER_NAME="${SESSION_NAME:-claude-resume}"
CLAUDE_ARGS="--dangerously-skip-permissions"
if [[ -n "${RESUME}" ]]; then
	if [[ -n "${SESSION_NAME}" ]]; then
		CLAUDE_ARGS="${CLAUDE_ARGS} --resume ${SESSION_NAME}"
	else
		CLAUDE_ARGS="${CLAUDE_ARGS} --resume"
	fi
else
	CLAUDE_ARGS="${CLAUDE_ARGS} --name ${SESSION_NAME}"
fi

PODMAN_CONF_DIR=$(mktemp -d)
cat > "${PODMAN_CONF_DIR}/containers.conf" << 'CONF'
[containers]
default_sysctls = []
userns = "host"
CONF

podman run -it --rm \
	--name "${CONTAINER_NAME}" \
	--privileged \
	--env HOME="${HOME}" \
	--tmpfs "${HOME}" \
	--tmpfs /run/podman \
	--device /dev/net/tun:/dev/net/tun \
	--device /dev/kvm \
	--device /dev/fuse \
	--security-opt label=disable \
	-w /workspace \
	-e CLAUDE_CODE_USE_VERTEX=$CLAUDE_CODE_USE_VERTEX \
	-e CLOUD_ML_REGION=$CLOUD_ML_REGION \
	-e ANTHROPIC_VERTEX_PROJECT_ID=$ANTHROPIC_VERTEX_PROJECT_ID \
	-e COLORTERM=truecolor \
	-e CONTAINERS_CONF=/tmp/containers-config/containers.conf \
	-e XDG_CONFIG_HOME=/tmp/config \
	-e DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus \
	-v ~/.claude:${HOME}/.claude \
	-v ~/.config/gcloud.claude:${HOME}/.config/gcloud:ro \
	-v ${PWD}:/workspace \
	-v podman-var:/var/lib/containers \
	-v "${PODMAN_CONF_DIR}/containers.conf":/tmp/containers-config/containers.conf:ro \
	-v "$(dirname "$(readlink -f "$0")")/claude-entrypoint.sh":/usr/local/bin/claude-entrypoint.sh:ro \
	-v /run/user/$(id -u)/bus:/run/user/$(id -u)/bus:ro \
	--entrypoint /usr/local/bin/claude-entrypoint.sh \
	--userns=keep-id \
	--group-add keep-groups \
	--user $(id -u):$(id -g) \
	$IMAGE ${CLAUDE_ARGS}
