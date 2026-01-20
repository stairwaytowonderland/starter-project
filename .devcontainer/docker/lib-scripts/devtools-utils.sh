#!/bin/sh

set -e

$LOGGER "Installing devtools utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

# * Always install system python3 and pip
apt-get -y install --no-install-recommends \
    tar \
    make \
    gnupg \
    && if [ "$PYTHON_VERSION" = "system" ]; then
        apt-get -y install --no-install-recommends \
            python3-pip \
            python3-venv \
            python3-dev \
            pipx
    fi

# Install Node.js (LTS version) and npm
# curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
#     && apt-get -y install --no-install-recommends nodejs

$LOGGER "Done! Devtools utilities installation complete."
