#!/usr/bin/env bash
# ./.devcontainer/docker/bin/clean.sh

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ]; then
    echo "Cannot determine script path"
    exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# docker rmi $(docker image ls -f dangling=true -q)
echo "Removing dangling Docker images..."
com=(docker rmi)
com+=("$(docker image ls -f dangling=true -q)")

# Deep clean docker system (use with caution)
# echo "Cleaning up Docker system (this may take a while)..."
# com=(docker system)
# com+=(prune)
# com+=(-a)
# com+=(--volumes)

set -- "${com[@]}"
. "$script_dir/exec-com.sh" "$@"
