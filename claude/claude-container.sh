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
	echo "Usage: $(basename $0) -s SESSION_NAME [-r] [build|config]"
	echo "  -s SESSION_NAME  session name (required)"
	echo "  -r               resume an existing session"
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

if [[ -z "${SESSION_NAME}" ]]; then
	echo "Error: session name is required (-s SESSION_NAME)"
	usage
	exit 1
fi

if [[ "${PWD}" == "${HOME}" ]]; then
	echo "You should not use claude on your home directory"
	usage
	exit 1
fi
CLAUDE_ARGS="--dangerously-skip-permissions"
if [[ -n "${RESUME}" ]]; then
	CLAUDE_ARGS="${CLAUDE_ARGS} --resume ${SESSION_NAME}"
else
	CLAUDE_ARGS="${CLAUDE_ARGS} --name ${SESSION_NAME}"
fi

podman run -it --rm \
   --name "${SESSION_NAME}" \
   --env HOME="${HOME}" \
   --tmpfs "${HOME}" \
	-e CLAUDE_CODE_USE_VERTEX=$CLAUDE_CODE_USE_VERTEX \
	-e CLOUD_ML_REGION=$CLOUD_ML_REGION \
	-e ANTHROPIC_VERTEX_PROJECT_ID=$ANTHROPIC_VERTEX_PROJECT_ID \
	-e COLORTERM=truecolor \
	-e CONTAINER_HOST=unix:///run/podman/podman.sock \
	-e XDG_CONFIG_HOME=/tmp/config \
	--security-opt label=disable \
	-v ~/.claude:${HOME}/.claude \
	-v ~/.config/gcloud.claude:${HOME}/.config/gcloud:ro \
	-v /run/user/$(id -u)/podman/podman.sock:/run/podman/podman.sock \
	-v ${PWD}:/workspace \
	-w /workspace \
	--userns=keep-id \
	--network host \
	--group-add keep-groups \
	--user $(id -u):$(id -g) \
	-v /run/user/$(id -u)/bus:/run/user/$(id -u)/bus:ro \
  -e DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus \
	$IMAGE claude ${CLAUDE_ARGS}
