#!/bin/sh

# * All variables are expected to be set via build args in the Dockerfile

set -e

LEVEL='ƒ' $LOGGER "Installing devtools utilities and dependencies..."

# shellcheck disable=SC1091
. /helpers/install-helper.sh

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

if [ -n "${NODEPATH-}" ] && [ -d "${NODEPATH-}" ]; then
    # ! NOTE: libatomic1 required if manually installing node and npm
    # ! (e.g. binary downloaded or copied from nodebuilder stage)
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
        cat << EOF
libatomic1
EOF
    )"

    update_and_install "${PACKAGES_TO_INSTALL# }"
else
    update_and_install "${PACKAGES_TO_INSTALL# }"

    # Install Node.js (LTS version) and npm
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
        && PACKAGES_TO_INSTALL="$(
            cat << EOF
nodejs
EOF
        )" \
        && $LOGGER "Node.js and npm packages: $PACKAGES_TO_INSTALL"

    update_and_install "${PACKAGES_TO_INSTALL# }"
fi

LEVEL='√' $LOGGER "Done! Devtools utilities installation complete."
