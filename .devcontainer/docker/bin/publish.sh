#!/usr/bin/env bash
# ./.devcontainer/docker/bin/publish.sh \
#   stairwaytowonderland

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ] ; then
  echo "Cannot determine script path"
  exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# Parse first argument as IMAGE_NAME, second as GITHUB_USER, third as IMAGE_VERSION
first_arg="${1-}"
[ -z "$first_arg" ] || shift

. "$script_dir/load_env.sh" "$script_dir/../../.."

GITHUB_TOKEN="${GITHUB_TOKEN-}"
GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
GITHUB_PAT="${GITHUB_PAT:-$GH_TOKEN}"
CR_PAT="${CR_PAT:-$GITHUB_PAT}"
REPO_NAMESPACE="${REPO_NAMESPACE-}"
REPO_NAME="${REPO_NAME-}"

# Determine IMAGE_NAME
IMAGE_NAME=${IMAGE_NAME:-$first_arg}
if [ -z "$IMAGE_NAME" ] ; then
  echo "Usage: $0 <image-name[:build_target]> [github-username] [image-version]"
  exit 1
fi
if awk -F':' '{print $2}' <<< "$IMAGE_NAME" >/dev/null 2>&1 ; then
  DOCKER_TARGET="$(awk -F':' '{print $2}' <<< "$IMAGE_NAME")"
  IMAGE_NAME="$(awk -F':' '{print $1}' <<< "$IMAGE_NAME")"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"devcontainer"}
# Determine GITHUB_USER
if [ $# -gt 0 ] ; then
  GITHUB_USER="${1:-$REPO_NAMESPACE}"
  shift
fi
if [ -z "${GITHUB_USER-}" ] ; then
  echo "Please provide your GitHub username as the first argument or set the REPO_NAMESPACE environment variable."
  exit 1
fi
# Determine IMAGE_VERSION
if [ $# -gt 0 ] ; then
  IMAGE_VERSION="${1-}"
  shift
fi
IMAGE_VERSION=${IMAGE_VERSION:-"latest"}

build_tag="${IMAGE_NAME}:${DOCKER_TARGET}"
docker_tag="${IMAGE_NAME}-${DOCKER_TARGET}:${IMAGE_VERSION}"
registry_url="ghcr.io/${GITHUB_USER}/${docker_tag}"

# Tag the image for GitHub Container Registry
echo "Tagging Docker image for GitHub Container Registry..."
# (set -x; docker tag "$build_tag" "$docker_tag")
(set -x; docker tag "$build_tag" "$registry_url" || true)
(set -x; docker rmi "$(docker images --filter label="org.opencontainers.image.title=${build_tag}" --filter dangling=true -q)" 2>/dev/null || true)

echo "Logging in to GitHub Container Registry..."
echo $CR_PAT | docker login ghcr.io -u $GITHUB_USER --password-stdin

echo "Publishing Docker image to GitHub Container Registry..."
com=(docker push)
com+=("$registry_url")

set -- "${com[@]}"
. "$script_dir/exec_com.sh" "$@"
