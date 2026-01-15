#!/usr/bin/env bash
# ./.devcontainer/docker/bin/build.sh \
#   starter-project \
#   --build-arg USERNAME=vscode \
#   --no-cache
#   --progress=plain
#   .

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ] ; then
  echo "Cannot determine script path"
  exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# Specify last argument as context if it's a directory
last_arg="${@: -1}"
# Parse first argument as IMAGE_NAME, second as REMOTE_USER (if not a build-arg or option)
first_arg="${1-}"
[ -z "$first_arg" ] || shift
# Check if next argument begins with '-' (indicating a build-arg or option)
# (if so, do not consume it as the second argument)
second_arg=""
flag=false
if [ $# -gt 0 ] ; then
  case "$1" in
    -*) ;;
    "$last_arg"*)
      [ $# -gt 1 ] || {
        second_arg="$1" ; shift
        last_arg=""
      }
      ;;
    *) second_arg="$1" ; shift ;;
  esac
else
  case "$first_arg" in
    "$last_arg"*) last_arg="" ;;
  esac
fi

. "$script_dir/load_env.sh" "$script_dir/../../.."

# Default repository info (must be provided as environment variables or build args)
REPO_NAME="${REPO_NAME}"
REPO_NAMESPACE="${REPO_NAMESPACE}"

# Determine Docker context
if [ -d "$last_arg" ] ; then
  DOCKER_CONTEXT="$last_arg"
else
  DOCKER_CONTEXT="${DOCKER_CONTEXT:-"$script_dir/../../.."}"
fi
if [ ! -d "$DOCKER_CONTEXT" ] ; then
  echo "Docker context directory not found at expected path: $DOCKER_CONTEXT"
  exit 1
fi
# Determine IMAGE_NAME and DOCKER_TARGET
IMAGE_NAME=${IMAGE_NAME:-$first_arg}
if [ -z "$IMAGE_NAME" ] ; then
  echo "Usage: $0 <image-name[:build_target]> [build-args...] [options] [context]"
  exit 1
fi
if awk -F':' '{print $2}' <<< "$IMAGE_NAME" >/dev/null 2>&1 ; then
  DOCKER_TARGET="$(awk -F':' '{print $2}' <<< "$IMAGE_NAME")"
  IMAGE_NAME="$(awk -F':' '{print $1}' <<< "$IMAGE_NAME")"
fi
DOCKER_TARGET=${DOCKER_TARGET:-"devcontainer"}
# Determine REMOTE_USER (the devcontainer non-root user, e.g., 'vscode' or 'devcontainer')
REMOTE_USER="${REMOTE_USER:-$second_arg}"

# Determine Dockerfile path and build tag
dockerfile_path="$DOCKER_CONTEXT/.devcontainer/docker/Dockerfile"
build_tag="${IMAGE_NAME}:${DOCKER_TARGET}"

if [ ! -f "$dockerfile_path" ] ; then
  echo "Dockerfile not found at expected path: $dockerfile_path"
  exit 1
fi

echo "Building Docker image for $DOCKER_TARGET..."
echo "Dockerfile path: $dockerfile_path"
echo "Docker context: $DOCKER_CONTEXT"
com=(docker build)
com+=("-f" "$dockerfile_path")
com+=("--label" "org.opencontainers.image.title=$build_tag")
com+=("--label" "org.opencontainers.image.source=https://github.com/$REPO_NAMESPACE/$REPO_NAME")
com+=("--label" "org.opencontainers.image.description=A simple Debian-based Docker image with essential development tools and Homebrew.")
com+=("--label" "org.opencontainers.image.licenses=MIT")
# If multi-arch, use annotations instead of labels
# https://docs.docker.com/reference/cli/docker/buildx/build/#annotation
# com+=("--annotation" "org.opencontainers.image.title=$build_tag")
# com+=("--annotation" "org.opencontainers.image.source=https://github.com/$REPO_NAMESPACE/$REPO_NAME")
# com+=("--annotation" "org.opencontainers.image.description=A simple Debian-based Docker image with essential development tools and Homebrew.")
# com+=("--annotation" "org.opencontainers.image.licenses=MIT")
com+=("--target" "$DOCKER_TARGET")
com+=("-t" "$build_tag")
if [ -n "$REMOTE_USER" ] ; then
  com+=("--build-arg" "USERNAME=$REMOTE_USER")
fi
com+=("--build-arg" "REPO_NAME=$REPO_NAME")
com+=("--build-arg" "REPO_NAMESPACE=$REPO_NAMESPACE")
for arg in "$@" ; do
  if [ "$arg" != "$DOCKER_CONTEXT" ] ; then
    com+=("$arg")
  fi
done
com+=("$DOCKER_CONTEXT")

set -- "${com[@]}"
. "$script_dir/exec_com.sh" "$@"
