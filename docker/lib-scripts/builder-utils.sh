#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='ƒ' $LOGGER "Installing common utilities and dependencies..."

# shellcheck disable=SC1091
. /helpers/install-helper.sh

# * Always install system Python3
PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
ca-certificates
gnupg2
lsb-release
procps
tzdata
wget
EOF
)"

update_and_install "${PACKAGES_TO_INSTALL# }"

LEVEL='√' $LOGGER "Done! Common utilities installation complete."
