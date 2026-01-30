#!/bin/sh

set -e

LEVEL='ƒ' $LOGGER "Installing common utilities and dependencies..."

# shellcheck disable=SC1091
. /helpers/install-helper.sh

# * Always install system Python3
PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
ca-certificates
gnupg2
curl
vim
nano
less
procps
lsb-release
tzdata
python3
jq
yq
EOF
)"

update_and_install "${PACKAGES_TO_INSTALL# }"

LEVEL='√' $LOGGER "Done! Common utilities installation complete."
