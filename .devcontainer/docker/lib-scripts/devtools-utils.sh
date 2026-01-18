#!/usr/bin/env bash

set -e

# This script installs common utilities and dependencies

# Install common packages
$LOGGER "Installing devtools utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

# * Always install system python3 and pip
apt-get -y install --no-install-recommends \
    gnupg \
    openssh-client \
    shfmt \
    python3-pip \
    && if [ "$PYTHON_VERSION" = "system" ]; then
        apt-get -y install --no-install-recommends \
            python3-venv \
            python3-dev \
            pipx
    fi

# Install Node.js (LTS version) and npm
# curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
#     && apt-get -y install --no-install-recommends nodejs

$LOGGER "Done! Devtools utilities installation complete."
