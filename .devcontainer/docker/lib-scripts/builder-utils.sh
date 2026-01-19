#!/bin/sh

set -e

$LOGGER "Installing common utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

# * Always install system python3
apt-get -y install --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    gnupg2 \
    curl \
    wget \
    unzip \
    vim \
    nano \
    less \
    procps \
    lsb-release \
    tzdata \
    jq \
    yq \
    python-is-python3

$LOGGER "Done! Common utilities installation complete."
