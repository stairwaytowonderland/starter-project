#!/usr/bin/env bash
# shellcheck disable=SC1091

# ./.devcontainer/docker/bin/build.sh \
#   starter-project \
#   --build-arg USERNAME=vscode \
#   --build-arg PYTHON_VERSION=devcontainer \
#   --no-cache
#   --progress=plain
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

# Specify last argument as context if it's a directory
last_arg="${*: -1}"
# Parse first argument as IMAGE_NAME, second as REMOTE_USER (if not a build-arg or option)
first_arg="${1-}"
[ -z "$first_arg" ] || shift
# Check if next argument begins with '-' (indicating a build-arg or option)
# (if so, do not consume it as the second argument)
second_arg=""
if [ $# -gt 0 ]; then
    case "$1" in
        -*) ;;
        "$last_arg"*)
            [ $# -gt 1 ] || {
                second_arg="$1"
                shift
                last_arg=""
            }
            ;;
        *)
            second_arg="$1"
            shift
            ;;
    esac
else
    case "$first_arg" in
        "$last_arg"*) last_arg="" ;;
    esac
fi

. "$script_dir/load-env.sh" "$script_dir/.."

BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-ubuntu}"
BASE_IMAGE_VARIANT="${BASE_IMAGE_VARIANT:-latest}"

# Default repository info (must be provided as environment variables or build args)
REPO_NAME="${REPO_NAME-}"
REPO_NAMESPACE="${REPO_NAMESPACE-}"

# Determine Docker context
if [ -d "$last_arg" ]; then
    BUILD_CONTEXT="$last_arg"
else
    BUILD_CONTEXT="${BUILD_CONTEXT:-"$script_dir/../../.."}"
fi
if [ ! -d "$BUILD_CONTEXT" ]; then
    echo "Docker context directory not found at expected path: $BUILD_CONTEXT"
    exit 1
fi
# Determine IMAGE_NAME and DOCKER_TARGET
IMAGE_NAME=${IMAGE_NAME:-$first_arg}
if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name[:build_target]> [build-args...] [options] [context]"
    exit 1
fi
if [ -n "${IMAGE_NAME##*:}" ] && [ "${IMAGE_NAME##*:}" != "$IMAGE_NAME" ]; then
    DOCKER_TARGET="${IMAGE_NAME##*:}"
    IMAGE_NAME="${IMAGE_NAME%%:*}"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"base"}
# Determine REMOTE_USER (the devcontainer non-root user, e.g., 'vscode' or 'devcontainer')
REMOTE_USER="${REMOTE_USER:-$second_arg}"

tag_prefix="${IMAGE_NAME}:${DOCKER_TARGET}"
# Append base image name if variant is 'latest'
[ "$BASE_IMAGE_VARIANT" != "latest" ] || tag_prefix="${tag_prefix}-${BASE_IMAGE_NAME}"

build_tag="${tag_prefix}-${BASE_IMAGE_VARIANT}"

dockerfile_path="$BUILD_CONTEXT/.devcontainer/docker/Dockerfile"

if [ ! -f "$dockerfile_path" ]; then
    echo "Dockerfile not found at expected path: $dockerfile_path"
    exit 1
fi

echo "Building Docker image for $DOCKER_TARGET..."
echo "Dockerfile path: $dockerfile_path"
echo "Docker context: $BUILD_CONTEXT"
com=(docker build)
com+=("-f" "$dockerfile_path")
com+=("--label" "org.opencontainers.image.ref.name=$build_tag")
com+=("--label" "org.opencontainers.image.title=$REPO_NAME - $DOCKER_TARGET - $BASE_IMAGE_NAME - $BASE_IMAGE_VARIANT")
com+=("--label" "org.opencontainers.image.source=https://github.com/$REPO_NAMESPACE/$REPO_NAME")
com+=("--label" "org.opencontainers.image.description=A simple Debian-based Docker image with essential development tools and Homebrew.")
com+=("--label" "org.opencontainers.image.licenses=MIT")
com+=("--target" "$DOCKER_TARGET")
com+=("-t" "$build_tag")

com+=("--platform=linux/arm64,linux/amd64")

# The `debian:bookworm-slim` image provides a minimal base for development containers
com+=("--build-arg" "IMAGE_NAME=${BASE_IMAGE_NAME}")
com+=("--build-arg" "VARIANT=${BASE_IMAGE_VARIANT}")
if [ -n "$REMOTE_USER" ]; then
    com+=("--build-arg" "USERNAME=$REMOTE_USER")
fi
# com+=("--build-arg" "PYTHON_VERSION=${PYTHON_VERSION:-latest}")
com+=("--build-arg" "REPO_NAME=$REPO_NAME")
com+=("--build-arg" "REPO_NAMESPACE=$REPO_NAMESPACE")
com+=("--build-arg" "TIMEZONE=${TIMEZONE:-America/Chicago}")
com+=("--build-arg" "DEV=${DEV:-false}")
for arg in "$@"; do
    if [ "$arg" != "$BUILD_CONTEXT" ]; then
        com+=("$arg")
    fi
done
com+=("$BUILD_CONTEXT")

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"

echo "Done! Docker image build complete."
