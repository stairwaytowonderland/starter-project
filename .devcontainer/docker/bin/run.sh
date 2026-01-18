#!/usr/bin/env bash
# shellcheck disable=SC1091

# ./.devcontainer/docker/bin/run.sh \
#   starter-project:devcontainer \
#   vscode \
#   .

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ]; then
    echo "Cannot determine script path"
    exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# Parse first argument as IMAGE_NAME, second as REMOTE_USER

# Specify last argument as context if it's a directory
last_arg="${*: -1}"

. "$script_dir/load-env.sh" "$script_dir/.."

BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-ubuntu}"
BASE_IMAGE_VARIANT="${BASE_IMAGE_VARIANT:-latest}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <image-name[:build_target]> [remote-user] [context]"
    exit 1
fi
# Determine IMAGE_NAME and DOCKER_TARGET
IMAGE_NAME=${IMAGE_NAME:-$1}
shift
if awk -F':' '{print $2}' <<< "$IMAGE_NAME" > /dev/null 2>&1; then
    DOCKER_TARGET="$(awk -F':' '{print $2}' <<< "$IMAGE_NAME")"
    IMAGE_NAME="$(awk -F':' '{print $1}' <<< "$IMAGE_NAME")"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"devcontainer"}
if [ -d "$last_arg" ]; then
    DOCKER_CONTEXT="$last_arg"
else
    DOCKER_CONTEXT="${DOCKER_CONTEXT:-"$script_dir/../../.."}"
fi
if [ ! -d "$DOCKER_CONTEXT" ]; then
    echo "Docker context directory not found at expected path: $DOCKER_CONTEXT"
    exit 1
fi
# Determine REMOTE_USER
if [ $# -gt 0 ]; then
    if [ "$1" != "$DOCKER_CONTEXT" ]; then
        REMOTE_USER="${1-}"
        shift
    fi
fi
REMOTE_USER="${REMOTE_USER:-devcontainer}"

if docker image inspect "${IMAGE_NAME}:${DOCKER_TARGET}" > /dev/null 2>&1; then
    echo "Found Docker image '${IMAGE_NAME}:${DOCKER_TARGET}'"
    docker_tag="${IMAGE_NAME}:${DOCKER_TARGET}"
elif docker image inspect "${IMAGE_NAME}:${DOCKER_TARGET}-${BASE_IMAGE_VARIANT}" > /dev/null 2>&1; then
    echo "Found Docker image '${IMAGE_NAME}:${DOCKER_TARGET}-${BASE_IMAGE_VARIANT}'"
    docker_tag="${IMAGE_NAME}:${DOCKER_TARGET}-${BASE_IMAGE_VARIANT}"
elif docker image inspect "${IMAGE_NAME}:${DOCKER_TARGET}-${BASE_IMAGE_NAME}-${BASE_IMAGE_VARIANT}" > /dev/null 2>&1; then
    echo "Found Docker image '${IMAGE_NAME}:${DOCKER_TARGET}-${BASE_IMAGE_NAME}-${BASE_IMAGE_VARIANT}'"
    docker_tag="${IMAGE_NAME}:${DOCKER_TARGET}-${BASE_IMAGE_NAME}-${BASE_IMAGE_VARIANT}"
else
    echo "Docker image '${IMAGE_NAME}:${DOCKER_TARGET}' not found locally. Please build the image first."
    exit 1
fi

workspace_dir="/home/${REMOTE_USER}/workspace"

echo "Running Docker container for ${REMOTE_USER}..."
com=(docker run -it --rm)
# TZ not needed, but included for reference and clarity
com+=("-e" "TZ=${TIMEZONE:-America/Chicago}")
if [ "${DEV:-false}" = "true" ]; then
    com+=("-e" "DEV=true")
    com+=("-e" "RESET_ROOT_PASS=${RESET_ROOT_PASS:-false}")
    com+=("-e" "DEBUG=${DEBUG:-false}")
fi
while [ $# -gt 0 ]; do
    case "$1" in
        -e)
            com+=("-e" "$2")
            shift 2
            ;;
        --env=*)
            com+=("$1")
            shift
            ;;
        *)
            break
            ;;
    esac
done
com+=("-v" "${DOCKER_CONTEXT}:${workspace_dir}")
if [ "$DOCKER_TARGET" = "base" ]; then
    com+=("-v" "${DOCKER_CONTEXT}/.devcontainer/docker/lib-scripts:/tmp/lib-scripts:ro")
else
    if [ -d "$HOME/.ssh" ]; then
        com+=("-v" "$HOME/.ssh:/home/${REMOTE_USER}/.ssh:ro")
    fi
    if [ -r "$HOME/.gitconfig" ]; then
        com+=("-v" "$HOME/.gitconfig:/etc/gitconfig:ro")
    fi
    if [ "$DOCKER_TARGET" = "codeserver" ]; then
        com+=("-p" "${HOST_IP:-0.0.0.0}:${HOST_PORT:-8080}:${CONTAINER_PORT:-8080}")
    fi
fi
com+=("$docker_tag")

for arg in "$@"; do
    if [ "$arg" != "$DOCKER_CONTEXT" ]; then
        com+=("$arg")
    fi
done

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"

echo "Done! Docker container exited."
