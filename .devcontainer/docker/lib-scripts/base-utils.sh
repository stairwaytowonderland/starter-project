#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='ƒ' $LOGGER "Installing base utilities and dependencies..."

# shellcheck disable=SC1091
. /helpers/install-helper.sh

PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
openssh-client
EOF
)"

update_and_install "${PACKAGES_TO_INSTALL# }"

DEVEL_PACKAGES_TO_INSTALL="${DEVEL_PACKAGES_TO_INSTALL% } $(
    cat << EOF
pre-commit
EOF
)"

if [ "$PRE_COMMIT_ENABLED" = "true" ] && ! "$PIPX" > /dev/null 2>&1; then
    install_packages "${DEVEL_PACKAGES_TO_INSTALL# }"
fi

LEVEL='√' $LOGGER "Done! Base utilities installation complete."
