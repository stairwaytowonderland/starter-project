#!/bin/sh

set -e

LEVEL='ƒ' $LOGGER "Installing Go utilities..."

export DEBIAN_FRONTEND=noninteractive

apt-get update

PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
        cat << EOF
shfmt
EOF
)"

platform="$(uname -sm | tr '[:upper:]' '[:lower:]')"
go_os="${platform%% *}"
platform_arch="${platform##* }"

if [ "$platform_arch" = "x86_64" ]; then
    go_arch=amd64
elif [ "$platform_arch" = "aarch64" ]; then
    go_arch=arm64
fi

if [ -z "$go_arch" ]; then
    LEVEL=error $LOGGER "Unsupported architecture: $platform_arch"
    exit 1
fi

go_version="$(curl --silent https://go.dev/VERSION?m=text | xargs echo | cut -d' ' -f1)"
go_url="https://dl.google.com/go/${go_version}.${go_os}-${go_arch}.tar.gz"

rm -rf /usr/local/go
LEVEL='*' $LOGGER "Downloading Go $go_version from $go_url ..."
if (
    set -x
    curl -sSLf "$go_url" | tar -C /usr/local -xzf -
); then
    # export PATH="/usr/local/go/bin:$PATH"
    # shellcheck disable=SC2027,SC2086
    LEVEL='ƒ' $LOGGER "Installing "${PACKAGES_TO_INSTALL# }" via Go (os: $go_os, arch: $go_arch)..."
    GOPATH=/usr/local /usr/local/go/bin/go install mvdan.cc/sh/v3/cmd/shfmt@latest
    rm -rf /usr/local/go
else
    LEVEL='!' $LOGGER "Failed to download Go from $go_url"
    exit 1
fi

LEVEL='√' $LOGGER "Done! Go utilities installation complete."
