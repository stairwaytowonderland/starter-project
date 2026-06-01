#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='*' $LOGGER "Setting up code-server environment..."

sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/start-code-server \
    && sed -i "s|\$PASSGEN|$PASSGEN|g" /usr/local/bin/start-code-server

# shellcheck disable=SC1091
. /helpers/install-helper.sh

PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
tini
EOF
)"

update_and_install "${PACKAGES_TO_INSTALL# }"

LEVEL='√' $LOGGER "Done! code-server environment setup complete."
