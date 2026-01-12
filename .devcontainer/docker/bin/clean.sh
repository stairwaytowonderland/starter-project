#!/usr/bin/env bash
# ./.devcontainer/docker/bin/clean.sh

set -euo pipefail

# docker rmi $(docker image ls -f dangling=true -q)
echo "Removing dangling Docker images..."
com=(docker rmi)
com+=("$(docker image ls -f dangling=true -q)")
printf "\033[95;1m%s\033[0m\n" "$(echo ${com[@]})"

# Deep clean docker system (use with caution)
# echo "Cleaning up Docker system (this may take a while)..."
# com=(docker system)
# com+=(prune)
# com+=(-a)
# com+=(--volumes)
# printf "\033[95;1m%s\033[0m\n" "$(echo ${com[@]})"

set -x
"${com[@]}"
