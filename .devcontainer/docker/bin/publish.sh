#!/usr/bin/env bash
# shellcheck disable=SC1091

# ./.devcontainer/docker/bin/publish.sh \
#   stairwaytowonderland

echo "(ƒ) Preparing for Docker image publish (push)..." >&2

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ]; then
    echo "(!) Cannot determine script path" >&2
    exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# Parse first argument as IMAGE_NAME, second as REGISTRY_USER, third as IMAGE_VERSION
first_arg="${1-}"
[ -z "$first_arg" ] || shift

. "$script_dir/load-env.sh" "$script_dir/.."

# ---------------------------------------

LATEST_TARGET="${LATEST_TARGET:-base}"
REGISTRY_HOST="${REGISTRY_HOST:-ghcr.io}"
REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-GitHub}"
REGISTER_PROVIDER_FQDN="${REGISTER_PROVIDER_FQDN:-github.com}"

BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-ubuntu}"
BASE_IMAGE_VARIANT="${BASE_IMAGE_VARIANT:-latest}"
DEFAULT_PLATFORM="linux/$(uname -m)"

GITHUB_TOKEN="${GITHUB_TOKEN-}"
GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
GITHUB_PAT="${GITHUB_PAT:-$GH_TOKEN}"
CR_PAT="${CR_PAT:-$GITHUB_PAT}"
REPO_NAMESPACE="${REPO_NAMESPACE-}"
REPO_NAME="${REPO_NAME-}"

# Determine IMAGE_NAME
IMAGE_NAME=${first_arg:-$REPO_NAME}
if [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <image-name[:build_target]> [github-username] [image-version]" >&2
    exit 1
fi
if [ -n "${IMAGE_NAME##*:}" ] && [ "${IMAGE_NAME##*:}" != "$IMAGE_NAME" ]; then
    DOCKER_TARGET="${IMAGE_NAME##*:}"
    IMAGE_NAME="${IMAGE_NAME%%:*}"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"base"}
# Determine Container Registry username
if [ $# -gt 0 ]; then
    REGISTRY_USER="${1:-$REPO_NAMESPACE}"
    shift
fi
if [ -z "${REGISTRY_USER-}" ]; then
    echo "(!) Please provide your ${REGISTRY_PROVIDER} username as the first argument or set the REPO_NAMESPACE environment variable." >&2
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

title_prefix="$REPO_NAME - $DOCKER_TARGET"
if [ "$DOCKER_TARGET" = "filez" ]; then
    build_tag="$DOCKER_TARGET"
    docker_tag="${IMAGE_NAME}:${DOCKER_TARGET}"
else
    title_suffix=" - $BASE_IMAGE_NAME - $BASE_IMAGE_VARIANT"
    tag_prefix="${IMAGE_NAME}:${DOCKER_TARGET}"
    # Append base image name if variant is 'latest'
    [ "$BASE_IMAGE_VARIANT" != "latest" ] || tag_prefix="${tag_prefix}-${BASE_IMAGE_NAME}"

    build_tag="${tag_prefix}-${BASE_IMAGE_VARIANT}"
    docker_tag="${tag_prefix}-${tag_suffix}"
fi

registry_url="${REGISTRY_HOST}/${REGISTRY_USER}/${docker_tag}"

capitalize() {
    printf "%s" "$1" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}' | tr -d '\n'
}

build_date() {
    echo "(+) Retrieving build date from image: $1" >&2
    (
        set -x
        docker inspect -f '{{.Created}}' "$(docker images --no-trunc -q -f reference="$1")"
    )
    echo -e "\033[2m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m" >&2
}

base_image_name_cap="$(capitalize "$BASE_IMAGE_NAME")"
image_description="A simple ${base_image_name_cap:-Debian}-based Docker image with essential development tools and Homebrew."
image_title="${title_prefix}${title_suffix-}"
repo_source="https://${REGISTER_PROVIDER_FQDN}/${REPO_NAMESPACE}/${REPO_NAME}"
revision="$(git -C "$script_dir/../../.." rev-parse HEAD)"

IFS="," read -r -a platforms <<< "${PLATFORM:-$DEFAULT_PLATFORM}"
description_arch=""
title_arch=""
annotation_prefix="index:"
if [ ${#platforms[*]} -gt 1 ]; then
    annotation_prefix="index:"
    # if echo "${platforms[*]}" | grep -q "linux/amd64"; then
    #     annotation_prefix="manifest[linux/amd64]:"
    #     description_arch=" -- for AMD64."
    #     title_arch=" - AMD64"
    # elif echo "${platforms[*]}" | grep -q "linux/arm64"; then
    #     annotation_prefix="manifest[linux/arm64]:"
    #     description_arch=" -- for ARM64."
    #     title_arch=" - ARM64"
    # fi
fi

tag_image() {
    local source_image="$1"
    local target_image="$2"
    echo "(+) Preparing Docker image for $REGISTRY_PROVIDER Container Registry..." >&2
    echo "(*) Tagging Docker image '${source_image}' as '${target_image}'..." >&2
    (
        set -x
        docker tag "$source_image" "$target_image"
    )
    echo -e "\033[2m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m" >&2
}

tag_image "$build_tag" "$registry_url"

echo "(+) Logging in to $REGISTRY_PROVIDER Container Registry..." >&2
echo "$CR_PAT" | docker login "$REGISTRY_HOST" -u "$REGISTRY_USER" --password-stdin
echo -e "\033[2m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m" >&2

echo "(∫) Publishing Docker image to $REGISTRY_PROVIDER Container Registry..." >&2
com=(docker push)
com+=("$registry_url")

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"

if [ "$DOCKER_TARGET" = "$LATEST_TARGET" ] && [ "${LATEST:-false}" = "true" ]; then
    latest_tag="${IMAGE_NAME}:latest"
    registry_url="ghcr.io/${REGISTRY_USER}/${latest_tag}"

    echo "(*) Tagging with 'latest'..." >&2
    tag_image "$build_tag" "$registry_url"

    com=(docker push)
    com+=("$registry_url")

    set -- "${com[@]}"
    . "$script_dir/exec-com.sh" "$@"
fi

remove_danglers() {
    echo "(+) Removing dangling Docker images..." >&2
    (
        set -x
        docker images \
            --filter label="org.opencontainers.image.ref.name=${1}" \
            --filter dangling=true -q \
            | xargs -r docker rmi
    )
    echo -e "\033[2m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m" >&2
}

remove_danglers "$build_tag"

echo "(∫) Adding annotations to ${registry_url} ..." >&2

com=(docker buildx imagetools create)
com+=("-t" "${registry_url}")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.description=${image_description%.}${description_arch%.}.")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.title=${image_title%.}${title_arch# }")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.source=${repo_source}")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.version=${build_tag##*:}")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.revision=${revision}")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.created=$(build_date "$build_tag")")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.vendor=${REPO_NAMESPACE}")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.base.name=${BASE_IMAGE_NAME}")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.base.variant=${BASE_IMAGE_VARIANT}")
com+=("--annotation" "${annotation_prefix}org.opencontainers.image.licenses=MIT")
com+=("$registry_url")

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"

# Pull the manifest to ensure local availability
# echo "Pulling the published Docker image manifest to ensure local availability..."
# pull_com=(docker pull)
# pull_com+=("$registry_url")

# set -- "${pull_com[@]}"
# . "$script_dir/exec-com.sh" "$@"

echo "(√) Done! Docker image publishing complete." >&2
# echo "_______________________________________" >&2
echo >&2
