#!/bin/sh

# * All variables are expected to be set via build args in the Dockerfile

set -e

install_packages() {
    # shellcheck disable=SC2086
    LEVEL='*' $LOGGER "Installing the following packages: "$*
    # shellcheck disable=SC2086,SC2048
    apt-get -y install --no-install-recommends $*
}

LEVEL='*' $LOGGER "Installing devtools utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
tar
make
gnupg
EOF
)"

# ! CAUTION: Homebrew recommends `build-essential`, which is large; install only if needed.
# ! The reason is that some formulae require compilation during installation.
# ! For the same reason, if compiling Python from source, we need it too.
# Installing build-essential in this image as a convenience (this image is meant for development use anyway)
if type "$BREW" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
        cat << EOF
build-essential
gcc
EOF
    )"
fi

# Install Node.js (LTS version) and npm
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && PACKAGES_TO_INSTALL="$(
        cat << EOF
nodejs
EOF
    )" \
    && $LOGGER "Node.js and npm packages: $PACKAGES_TO_INSTALL"

install_packages "${PACKAGES_TO_INSTALL# }"

$LOGGER "Done! Devtools utilities installation complete."
