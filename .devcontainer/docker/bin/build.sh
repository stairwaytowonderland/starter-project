#!/usr/bin/env bash
# shellcheck disable=SC1091

# ./.devcontainer/docker/bin/build.sh \
#   starter-project \
#   --build-arg USERNAME=vscode \
#   --build-arg PYTHON_VERSION=devcontainer \
#   --no-cache
#   --progress=plain
#   .

echo "(ƒ) Preparing for Docker image build..." >&2

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

# ---------------------------------------

BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-ubuntu}"
BASE_IMAGE_VARIANT="${BASE_IMAGE_VARIANT:-latest}"
DEFAULT_PLATFORM="linux/$(uname -m)"

# Default repository info (must be provided as environment variables or build args)
REPO_NAME="${REPO_NAME:-docker}"
REPO_NAMESPACE="${REPO_NAMESPACE:-docker}"

# Determine Docker context
if [ -d "$last_arg" ]; then
    BUILD_CONTEXT="$last_arg"
else
    BUILD_CONTEXT="${BUILD_CONTEXT:-"$script_dir/../../.."}"
fi
if [ ! -d "$BUILD_CONTEXT" ]; then
    echo "(!) Docker context directory not found at expected path: $BUILD_CONTEXT" >&2
    exit 1
fi
# Determine IMAGE_NAME and DOCKER_TARGET
IMAGE_NAME=${IMAGE_NAME:-$first_arg}
if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name[:build_target]> [build-args...] [options] [context]" >&2
    exit 1
fi
if [ -n "${IMAGE_NAME##*:}" ] && [ "${IMAGE_NAME##*:}" != "$IMAGE_NAME" ]; then
    DOCKER_TARGET="${IMAGE_NAME##*:}"
    IMAGE_NAME="${IMAGE_NAME%%:*}"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"base"}
# Determine REMOTE_USER (the devcontainer non-root user, e.g., 'vscode' or 'devcontainer')
REMOTE_USER="${REMOTE_USER:-$second_arg}"

if [ "$DOCKER_TARGET" = "filez" ]; then
    build_tag="$DOCKER_TARGET"
else
    tag_prefix="${IMAGE_NAME}:${DOCKER_TARGET}"
    # Append base image name if variant is 'latest'
    [ "$BASE_IMAGE_VARIANT" != "latest" ] || tag_prefix="${tag_prefix}-${BASE_IMAGE_NAME}"

    build_tag="${tag_prefix}-${BASE_IMAGE_VARIANT}"
fi

dockerfile_path="$BUILD_CONTEXT/.devcontainer/docker/Dockerfile"

if [ ! -f "$dockerfile_path" ]; then
    echo "(!) Dockerfile not found at expected path: $dockerfile_path" >&2
    exit 1
fi

# dedupe() {
#     local str="${1}"
#     local -a temp_arr
#     [ -n "$str" ] || return $?
#     # Parse str into an array
#     IFS="," read -r -a temp_arr <<< "$str"
#     # Remove duplicate platforms from the array
#     read -r -a temp_arr <<< "$(printf '%s\n' "${temp_arr[@]}" | sort -u | xargs echo)"
#     # Return comma-separated string
#     local IFS=","
#     echo "${temp_arr[*]}"
# }
# build_platforms="$(dedupe "${PLATFORM:-linux/amd64,linux/arm64}")"
# # Split on comma to create array
# IFS="," read -r -a platforms <<< "${build_platforms}"

zoneinfo() {
    echo "(+) Determining timezone..." >&2
    local DEFAULT_TIMEZONE=UTC
    [ -n "${TIMEZONE-}" ] \
        || DEFAULT_TIMEZONE=$(
            set -eox pipefail
            readlink /etc/localtime 2> /dev/null | grep zoneinfo | sed 's|.*/zoneinfo/||' \
                || echo UTC
        )
    tz="${TIMEZONE:-$DEFAULT_TIMEZONE}"
    echo "$tz"
    echo "(∞) Timezone determined: $tz" >&2
    echo -e "\033[2m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m" >&2
}

echo "(*) Building Docker image for $DOCKER_TARGET..." >&2
echo "(*) Dockerfile path: $dockerfile_path" >&2
echo "(*) Docker context: $BUILD_CONTEXT" >&2
com=(docker build)
com+=("-f" "$dockerfile_path")
com+=("--label" "org.opencontainers.image.ref.name=$build_tag")
com+=("--target" "$DOCKER_TARGET")
com+=("-t" "$build_tag")
com+=("--platform=${PLATFORM:-$DEFAULT_PLATFORM}")
# The `debian:bookworm-slim` image provides a minimal base for development containers
com+=("--build-arg" "IMAGE_NAME=${BASE_IMAGE_NAME}")
com+=("--build-arg" "VARIANT=${BASE_IMAGE_VARIANT}")
if [ -n "$REMOTE_USER" ]; then
    com+=("--build-arg" "USERNAME=$REMOTE_USER")
fi
# com+=("--build-arg" "PYTHON_VERSION=${PYTHON_VERSION:-latest}")
com+=("--build-arg" "TIMEZONE=$(zoneinfo)")
com+=("--build-arg" "DEV=${DEV:-false}")
for arg in "$@"; do
    if [ "$arg" != "$BUILD_CONTEXT" ]; then
        com+=("$arg")
    fi
done
com+=("$BUILD_CONTEXT")

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"

echo "(√) Done! Docker image build complete." >&2
echo "_______________________________________" >&2
echo >&2
