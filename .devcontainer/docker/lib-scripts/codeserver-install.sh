#!/usr/bin/env bash

# https://coder.com/docs/code-server/install#debian-ubuntu

set -e

VERSION="${CODESERVER_VERSION:-latest}"

TOOL_LABEL="code-server"
GITHUB_REPO="coder/code-server"
DOWNLOAD_PREFIX="https://github.com/${GITHUB_REPO}/releases/download/v"
DOWNLOAD_STANDALONE="${DOWNLOAD_STANDALONE:-false}"

LEVEL='ƒ' $LOGGER "Installing $TOOL_LABEL utilities..."

if [ "$VERSION" = "latest" ]; then
    VERSION="$(curl -sSLf https://api.github.com/repos/${GITHUB_REPO}/releases/latest \
        | jq -r .tag_name | sed 's/^v//')"
fi

# shellcheck disable=SC1091
. /helpers/install-helper.sh

if __set_url_parts "$GITHUB_REPO" "$VERSION" "$DOWNLOAD_PREFIX"; then
    build_url() {
        if [ "$DOWNLOAD_STANDALONE" != "true" ]; then
            download_file="code-server_${DOWNLOAD_VERSION#v}_${DOWNLOAD_ARCH}.deb"
        else
            download_file="code-server-${DOWNLOAD_VERSION#v}-${DOWNLOAD_OS}-${DOWNLOAD_ARCH}.tar.gz"
        fi
        # url_prefix="https://github.com/coder/code-server/releases/download/v"
        echo "${DOWNLOAD_URL_PREFIX}${DOWNLOAD_VERSION}/${download_file}"
    }
    DOWNLOAD_URL="$(build_url)"
else
    LEVEL='!' $LOGGER "Failed to determine download parameters for code-server version $VERSION"
    exit 1
fi

INSTALL_PREFIX="$HOME/.local/lib"
mkdir -p "$INSTALL_PREFIX" "$HOME/.local/bin"
rm -rf "$INSTALL_PREFIX/code-server-$DOWNLOAD_VERSION"

LEVEL='*' $LOGGER "Downloading $TOOL_LABEL $DOWNLOAD_VERSION..."
if [ "$DOWNLOAD_STANDALONE" != "true" ]; then
    __install_from_package "$DOWNLOAD_URL"
elif __install_from_tarball "$DOWNLOAD_URL" "$INSTALL_PREFIX"; then
    (
        set -x
        mv "$INSTALL_PREFIX/code-server-$DOWNLOAD_VERSION-$DOWNLOAD_OS-$DOWNLOAD_ARCH" "$INSTALL_PREFIX/code-server-$DOWNLOAD_VERSION"
    )
    ln -s "$INSTALL_PREFIX/code-server-$DOWNLOAD_VERSION/bin/code-server" "$HOME/.local/bin/code-server"
    # update-alternatives --install "$HOME/.local/bin/code-server" code-server "$INSTALL_PREFIX/code-server-$DOWNLOAD_VERSION/bin/code-server" 1
else
    LEVEL='!' $LOGGER "Failed to download $TOOL_LABEL from $DOWNLOAD_URL"
    exit 1
fi

LEVEL='√' $LOGGER "Done! $TOOL_LABEL utilities installation complete."
