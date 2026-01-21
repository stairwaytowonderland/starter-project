#!/bin/sh

set -e

SHFMT_ENABLED="${SHFMT_ENABLED:-false}"

$LOGGER "Installing base utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

PACKAGES_TO_INSTALL="$(
    cat << EOF
openssh-client
EOF
)"

# ! CAUTION: `shfmt` (for shell script formatting) requires Go,
# ! and has many CVEs in the Go toolchain; Install only if requested
if [ "$SHFMT_ENABLED" = "true" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
        cat << EOF
shfmt
EOF
    )"
fi

# shellcheck disable=SC2086
$LOGGER "Installing the following packages: "$PACKAGES_TO_INSTALL

# shellcheck disable=SC2086
apt-get -y install --no-install-recommends $PACKAGES_TO_INSTALL

$LOGGER "Done! Base utilities installation complete."
