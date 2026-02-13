#!/bin/bash

export CLOUDSDK_CONFIG=~/.config/gcloud.claude
IMAGE=claude


build () {
	cd $HOME/src/myscripts/claude/images && podman build -t $IMAGE .
}

config () {
	gcloud init
	gcloud auth application-default login
	gcloud auth application-default set-quota-project cloudability-it-gemini
}

usage () {
	echo "Usage: $(basename $0) [build|config|DIRECTORY]"
}

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


if [[ "${PWD}" == "${HOME}" ]]; then
	echo "You should not use claude on your home directory"
	usage
	exit 1
fi
podman run -it --rm \
   --env HOME="${HOME}" \
   --tmpfs "${HOME}" \
	-e CLAUDE_CODE_USE_VERTEX=$CLAUDE_CODE_USE_VERTEX \
	-e CLOUD_ML_REGION=$CLOUD_ML_REGION \
	-e ANTHROPIC_VERTEX_PROJECT_ID=$ANTHROPIC_VERTEX_PROJECT_ID \
	-e COLORTERM=truecolor \
	-v ~/.config/gcloud.claude:${HOME}/.config/gcloud:ro,z \
	-v ${PWD}:/workspace:z \
	-w /workspace \
	--userns=keep-id \
	--user $(id -u):$(id -g) \
	$IMAGE claude
