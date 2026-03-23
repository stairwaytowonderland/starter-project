#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='ƒ' $LOGGER "Installing devuser utilities and dependencies..."

# shellcheck disable=SC1091
. /helpers/install-helper.sh

# * Install sudo here so production image doesn't have it
ESSENTIAL_PACKAGES="${ESSENTIAL_PACKAGES% } $(
    cat << EOF
sudo
nano
less
jq
bash-completion
EOF
)"

BUILD_PACKAGES="${BUILD_PACKAGES% } $(
    cat << EOF
software-properties-common
EOF
)"

for pkg in $ESSENTIAL_PACKAGES $BUILD_PACKAGES; do
    if ! dpkg -s "$pkg" > /dev/null 2>&1; then
        PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $pkg"
    fi
done

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

remove_packages "${BUILD_PACKAGES# }"

LEVEL='√' $LOGGER "Done! Devuser utilities installation complete."
