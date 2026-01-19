#!/bin/sh

set -e

$LOGGER "Installing base utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

apt-get -y install --no-install-recommends \
    shfmt \
    openssh-client

$LOGGER "Done! Base utilities installation complete."
