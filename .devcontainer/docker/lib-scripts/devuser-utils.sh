#!/bin/sh

set -e

# * Not currently a build arg but could be in future
USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"

$LOGGER "Installing devuser utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

# * Install sudo here so production image doesn't have it
apt-get -y install --no-install-recommends \
    sudo \
    bash-completion \
    software-properties-common

# * We don't want to use --no-install-recommends here
# since the additional utilities (games) may depend on some recommended packages.
apt-get -y install \
    cowsay \
    fortune

$LOGGER "Done! Devuser utilities installation complete."
