#!/bin/sh

set -e

USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"

$LOGGER "Installing devuser utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

# * Install sudo here so production image doesn't have it
# * Also install python because pre-commit requires it
apt-get -y install --no-install-recommends \
    sudo \
    bash-completion \
    software-properties-common

# * Install GIT
/tmp/lib-scripts/git-install.sh

# * We don't want to use --no-install-recommends here
# since the additional utilities (games) may depend on some recommended packages.
apt-get -y install \
    cowsay \
    fortune

$LOGGER "Done! Devuser utilities installation complete."
