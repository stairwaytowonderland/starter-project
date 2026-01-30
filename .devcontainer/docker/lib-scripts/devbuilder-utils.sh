#!/bin/sh

set -e

LEVEL='ƒ' $LOGGER "Installing devuser utilities and dependencies..."

# shellcheck disable=SC1091
. /helpers/install-helper.sh

# * Install sudo here so production image doesn't have it
PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
sudo
bash-completion
software-properties-common
EOF
)"

update_and_install "${PACKAGES_TO_INSTALL# }"

# * We don't want to use --no-install-recommends here
# since the additional utilities (games) may depend on some recommended packages.
PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
cowsay
fortune
EOF
)"

install_packages --install-recommends "${PACKAGES_TO_INSTALL# }"

LEVEL='√' $LOGGER "Done! Devuser utilities installation complete."
