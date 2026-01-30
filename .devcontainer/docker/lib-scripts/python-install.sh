#!/bin/sh

# * All variables are expected to be set via build args in the Dockerfile

set -e

USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"

# shellcheck disable=SC1091
. /helpers/install-helper.sh

LEVEL='ƒ' $LOGGER "Installing Python utilities..."

if [ "$PYTHON_VERSION" = "system" ] \
    || { ! type "$BREW" > /dev/null 2>&1 && [ "$PYTHON_VERSION" = "latest" ]; }; then

    if [ "$PYTHON_VERSION" = "latest" ]; then
        if [ "$IMAGE_NAME" = "ubuntu" ] && [ "$USE_PPA_IF_AVAILABLE" = "true" ]; then
            PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
                cat << EOF
python3.14
python3.14-venv
python3.14-dev
pipx
EOF
            )"

            add-apt-repository ppa:deadsnakes/ppa -y
            update_and_install "${PACKAGES_TO_INSTALL# }"

            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 2
        fi
    fi

    if [ -z "$PACKAGES_TO_INSTALL" ] && [ "$PYTHON_VERSION" = "latest" ]; then
        PACKAGES_TO_INSTALL="$(
            cat << EOF
python3
python3-pip
python3-venv
python3-dev
pipx
EOF
        )"
        install_packages "${PACKAGES_TO_INSTALL# }"
    fi
fi

LEVEL='√' $LOGGER "Done! Python utilities installation complete."
