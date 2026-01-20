#!/usr/bin/env bash
# shellcheck disable=SC1091

# ./.devcontainer/docker/bin/publish.sh \
#   stairwaytowonderland

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ]; then
    echo "Cannot determine script path"
    exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

LATEST_TARGET="${LATEST_TARGET:-base}"

# Parse first argument as IMAGE_NAME, second as GITHUB_USER, third as IMAGE_VERSION
first_arg="${1-}"
[ -z "$first_arg" ] || shift

. "$script_dir/load-env.sh" "$script_dir/.."

BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-ubuntu}"
BASE_IMAGE_VARIANT="${BASE_IMAGE_VARIANT:-latest}"

GITHUB_TOKEN="${GITHUB_TOKEN-}"
GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
GITHUB_PAT="${GITHUB_PAT:-$GH_TOKEN}"
CR_PAT="${CR_PAT:-$GITHUB_PAT}"
REPO_NAMESPACE="${REPO_NAMESPACE-}"
REPO_NAME="${REPO_NAME-}"

# Determine IMAGE_NAME
IMAGE_NAME=${first_arg:-$REPO_NAME}
if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name[:build_target]> [github-username] [image-version]"
    exit 1
fi
if awk -F':' '{print $2}' <<< "$IMAGE_NAME" > /dev/null 2>&1; then
    DOCKER_TARGET="$(awk -F':' '{print $2}' <<< "$IMAGE_NAME")"
    IMAGE_NAME="$(awk -F':' '{print $1}' <<< "$IMAGE_NAME")"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"base"}
# Determine GITHUB_USER
if [ $# -gt 0 ]; then
    GITHUB_USER="${1:-$REPO_NAMESPACE}"
    shift
fi
if [ -z "${GITHUB_USER-}" ]; then
    echo "Please provide your GitHub username as the first argument or set the REPO_NAMESPACE environment variable."
    exit 1
fi
# Determine IMAGE_VERSION
if [ $# -gt 0 ]; then
    IMAGE_VERSION="${1-}"
    shift
fi
IMAGE_VERSION="${IMAGE_VERSION:-latest}"

tag_suffix="${BASE_IMAGE_VARIANT}"
# Append image version if not 'latest'
[ "$IMAGE_VERSION" = "latest" ] || tag_suffix="${tag_suffix}-${IMAGE_VERSION}"

tag_prefix="${IMAGE_NAME}:${DOCKER_TARGET}"
# Append base image name if variant is 'latest'
[ "$BASE_IMAGE_VARIANT" != "latest" ] || tag_prefix="${tag_prefix}-${BASE_IMAGE_NAME}"

build_tag="${tag_prefix}-${BASE_IMAGE_VARIANT}"
docker_tag="${tag_prefix}-${tag_suffix}"

registry_url="ghcr.io/${GITHUB_USER}/${docker_tag}"

tag_image() {
    local source_image="$1"
    local target_image="$2"

    echo "Tagging Docker image '${source_image}' as '${target_image}'..."
    (
        set -x
        docker tag "$source_image" "$target_image"
    )
}

remove_danglers() {
    echo "Removing dangling Docker images..."
    (
        set -x
        docker rmi "$(docker images --filter label="org.opencontainers.image.ref.name=${1}" --filter dangling=true -q)" 2> /dev/null || true
    )
}

# Tag the image for GitHub Container Registry
echo "Tagging Docker image for GitHub Container Registry..."
# (set -x; docker tag "$build_tag" "$docker_tag")
tag_image "$build_tag" "$registry_url"

echo "Logging in to GitHub Container Registry..."
echo "$CR_PAT" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

echo "Publishing Docker image to GitHub Container Registry..."
com=(docker push)
com+=("$registry_url")

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"

if [ "$DOCKER_TARGET" = "$LATEST_TARGET" ] && [ "${LATEST:-false}" = "true" ]; then
    latest_tag="${IMAGE_NAME}:latest"
    registry_url_latest="ghcr.io/${GITHUB_USER}/${latest_tag}"

    echo "Tagging Docker image with 'latest' tag for GitHub Container Registry..."
    tag_image "$build_tag" "$registry_url_latest"

    com=(docker push)
    com+=("$registry_url_latest")

    set -- "${com[@]}"
    . "$script_dir/exec-com.sh" "$@"
fi

remove_danglers "$build_tag"
echo "Done! Docker image publishing complete."
