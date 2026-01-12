#!/usr/bin/env bash
# ./.devcontainer/docker/bin/run.sh \
#   simple-project:devcontainer \
#   vscode \
#   .

set -euo pipefail

if [ -z "$0" ] ; then
  echo "Cannot determine script path"
  exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
last_arg="${@: -1}"

if [ $# -lt 1 ] ; then
  echo "Usage: $0 <image-name[:build_target]> [remote-user] [context]"
  exit 1
fi
IMAGE_NAME=${IMAGE_NAME:-$1}
shift
if awk -F':' '{print $2}' <<< "$IMAGE_NAME" >/dev/null 2>&1 ; then
  DOCKER_TARGET="$(awk -F':' '{print $2}' <<< "$IMAGE_NAME")"
  IMAGE_NAME="$(awk -F':' '{print $1}' <<< "$IMAGE_NAME")"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"devcontainer"}
if [ -d "$last_arg" ] ; then
  DOCKER_CONTEXT="$last_arg"
else
  DOCKER_CONTEXT="${DOCKER_CONTEXT:-"$script_dir/../../.."}"
fi
if [ $# -gt 0 ] ; then
  if [ "$1" != "$DOCKER_CONTEXT" ] ; then
    REMOTE_USER="${1-}"
    shift
  fi
fi
REMOTE_USER="${REMOTE_USER:-devcontainer}"

workspace_dir="/home/${REMOTE_USER}/workspace"
docker_tag="${IMAGE_NAME}:${DOCKER_TARGET}"

if [ ! -d "$DOCKER_CONTEXT" ] ; then
  echo "Docker context directory not found at expected path: $DOCKER_CONTEXT"
  exit 1
fi

echo "Running Docker container for ${REMOTE_USER}..."
com=(docker run -it --rm)
com+=("-e" "DEBUG=${DEBUG:-false}")
com+=("-e" "DEV=${DEV:-false}")
com+=("-v" "${DOCKER_CONTEXT}:${workspace_dir}")
com+=("-p" "0.0.0.0:8080:8080")
com+=("$docker_tag")
for arg in "$@" ; do
  if [ "$arg" != "$DOCKER_CONTEXT" ] ; then
    com+=("$arg")
  fi
done
printf "\033[95;1m%s\033[0m\n" "$(echo ${com[@]})"

set -x
"${com[@]}"
