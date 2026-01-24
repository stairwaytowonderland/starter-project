#!/bin/sh

set -e

LEVEL='*' $LOGGER "Installing base utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
openssh-client
EOF
)"

if [ "$PRE_COMMIT_ENABLED" = "true" ] \
    && ! "$PIPX" > /dev/null 2>&1 \
    && ! type "$BREW" > /dev/null 2>&1; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
        cat << EOF
pre-commit
EOF
    )"
fi

# shellcheck disable=SC2086
LEVEL='*' $LOGGER "Installing the following packages: ${PACKAGES_TO_INSTALL# }"

# shellcheck disable=SC2086
apt-get -y install --no-install-recommends ${PACKAGES_TO_INSTALL# }

$LOGGER "Done! Base utilities installation complete."
