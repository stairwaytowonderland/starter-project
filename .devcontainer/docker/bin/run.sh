#!/usr/bin/env bash
# shellcheck disable=SC1091

# [REMOTE_HUB=<your-remote-hub>] ./.devcontainer/docker/bin/run.sh \
#   starter-project:devcontainer \
#   vscode \
#   .

echo "(ƒ) Preparing to run Docker container..." >&2

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ]; then
    echo "(!) Cannot determine script path" >&2
    exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# Specify last argument as context if it's a directory
last_arg="${*: -1}"

. "$script_dir/load-env.sh" "$script_dir/.."

# ---------------------------------------

CODESERVER_BIND_ADDR="${CODESERVER_BIND_ADDR:-0.0.0.0:13337}"
CODESERVER_CONTAINER_PORT="${CODESERVER_CONTAINER_PORT:-${CODESERVER_BIND_ADDR##*:}}"
CODESERVER_HOST_PORT="${CODESERVER_HOST_PORT:-$CODESERVER_CONTAINER_PORT}"
CODESERVER_HOST_IP="${CODESERVER_HOST_IP:-${CODESERVER_BIND_ADDR%%:*}}"

BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-ubuntu}"
BASE_IMAGE_VARIANT="${BASE_IMAGE_VARIANT:-latest}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <image-name[:build_target]> [remote-user] [context]" >&2
    exit 1
fi
# Determine IMAGE_NAME and DOCKER_TARGET
IMAGE_NAME=${IMAGE_NAME:-$1}
shift
if [ -n "${IMAGE_NAME##*:}" ] && [ "${IMAGE_NAME##*:}" != "$IMAGE_NAME" ]; then
    DOCKER_TARGET="${IMAGE_NAME##*:}"
    IMAGE_NAME="${IMAGE_NAME%%:*}"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"base"}
if [ -d "$last_arg" ]; then
    RUN_CONTEXT="$last_arg"
else
    RUN_CONTEXT="${RUN_CONTEXT:-"$script_dir/../../.."}"
fi
if [ ! -d "$RUN_CONTEXT" ]; then
    echo "(!) Docker context directory not found at expected path: $RUN_CONTEXT" >&2
    exit 1
fi
# Determine REMOTE_USER
if [ $# -gt 0 ]; then
    if [ "$1" != "$RUN_CONTEXT" ]; then
        REMOTE_USER="${1-}"
        shift
    fi
fi
REMOTE_USER="${REMOTE_USER:-devcontainer}"
IMAGE_VERSION="${IMAGE_VERSION:-latest}"

REMOTE_HUB="${REMOTE_HUB-}"
if [ -n "$REMOTE_HUB" ]; then
    docker_tag="${REMOTE_HUB}/${IMAGE_NAME}:${DOCKER_TARGET}"
else
    tag_suffix="${BASE_IMAGE_VARIANT}"
    # Append image version if not 'latest'
    [ "$IMAGE_VERSION" = "latest" ] || tag_suffix="${tag_suffix}-${IMAGE_VERSION}"

    tag_prefix="${IMAGE_NAME}:${DOCKER_TARGET}"
    # Append base image name if variant is 'latest'
    [ "$BASE_IMAGE_VARIANT" != "latest" ] || tag_prefix="${tag_prefix}-${BASE_IMAGE_NAME}"

    build_tag="${tag_prefix}-${BASE_IMAGE_VARIANT}"
    publish_tag="${tag_prefix}-${tag_suffix}"

    build_id="$(docker images -q "${build_tag}")"
    publish_id="$(docker images -q "${publish_tag}")"
    image_id="${build_id:-$publish_id}"

    echo "(*) Looking for Docker image id '${image_id}' ('${build_tag}' or '${publish_tag}') locally..." >&2

    if docker image inspect "$build_id" > /dev/null 2>&1; then
        echo "(*) Found Docker image '${build_tag}'" >&2
        docker_tag="${build_tag}"
    elif docker image inspect "$publish_id" > /dev/null 2>&1; then
        echo "(*) Found Docker image '${publish_tag}'" >&2
        docker_tag="${publish_tag}"
    else
        echo "(!) Docker image not found locally. Please build the image first." >&2
        exit 1
    fi
fi

workspace_dir="/home/${REMOTE_USER}/workspace"

echo "(*) Running Docker container for ${REMOTE_USER}..." >&2
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
if [ "$DOCKER_TARGET" = "builder" ]; then
    com+=("-v" "${RUN_CONTEXT}/.devcontainer/docker/helpers:/helpers:ro")
    com+=("-v" "${RUN_CONTEXT}/.devcontainer/docker/lib-scripts:/tmp/lib-scripts:ro")
else
    com+=("-v" "${RUN_CONTEXT}:${workspace_dir}")
    if [ -d "$HOME/.ssh" ]; then
        com+=("-v" "$HOME/.ssh:/home/${REMOTE_USER}/.ssh:ro")
    fi
    if [ -r "$HOME/.gitconfig" ]; then
        com+=("-v" "$HOME/.gitconfig:/etc/gitconfig:ro")
    fi
    if echo "$DOCKER_TARGET" | grep -qE "^codeserver"; then
        com+=("-p" "${CODESERVER_HOST_IP}:${CODESERVER_HOST_PORT}:${CODESERVER_CONTAINER_PORT}")
    fi
fi
com+=("$docker_tag")

for arg in "$@"; do
    if [ "$arg" != "$RUN_CONTEXT" ]; then
        com+=("$arg")
    fi
done

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"

echo "(√) Done! Docker container exited." >&2
# echo "_______________________________________" >&2
echo >&2
