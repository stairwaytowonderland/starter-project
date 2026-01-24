#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

VERSION="${NODE_VERSION:-latest}"

TOOL_LABEL="Node.js"
GITHUB_REPO="nodejs/node"
DOWNLOAD_PREFIX="https://nodejs.org/dist/v"

NODEJS_HOME="${NODEJS_HOME:-/usr/local/lib/node/nodejs}"

LEVEL='*' $LOGGER "Installing $TOOL_LABEL..."

if [ "$VERSION" = "latest" ]; then
    VERSION="$(curl -sSLf https://api.github.com/repos/$GITHUB_REPO/releases/latest \
        | jq -r .tag_name | sed 's/^v//')"
fi

# * NOTE: libatomic1 required for node and npm
PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
libatomic1
EOF
)"

# shellcheck disable=SC1091
. /tmp/lib-scripts/install-helper.sh

update_and_install "${PACKAGES_TO_INSTALL# }"

if __set_url_parts "$GITHUB_REPO" "$VERSION" "v" "$DOWNLOAD_PREFIX"; then
    build_url() {
        echo "${DOWNLOAD_URL_PREFIX}/${DOWNLOAD_VERSION}/node-${DOWNLOAD_VERSION}-${DOWNLOAD_OS}-${DOWNLOAD_ARCH}.tar.gz"
    }
    DOWNLOAD_URL="$(build_url)"
else
    LEVEL='!' $LOGGER "Failed to determine download parameters for $TOOL_LABEL version $VERSION"
    exit 1
fi

INSTALL_PREFIX="$HOME/.local/lib"
rm -rf "$INSTALL_PREFIX/node-$DOWNLOAD_VERSION"

LEVEL='*' $LOGGER "Downloading $TOOL_LABEL $DOWNLOAD_VERSION..."
if (
    __download_tar "$DOWNLOAD_URL" "$INSTALL_PREFIX"
); then
    (
        set -x
        mv "$INSTALL_PREFIX/node-$DOWNLOAD_VERSION-$DOWNLOAD_OS-$DOWNLOAD_ARCH" "$INSTALL_PREFIX/node-$DOWNLOAD_VERSION"
    )
    ln -s "$INSTALL_PREFIX/node-$DOWNLOAD_VERSION" "$NODEJS_HOME"
    # ln -s "$NODEJS_HOME/bin/node" "$HOME/.local/bin/node"
    cat > /tmp/alternatives << EOF
#!/bin/sh
set -e
LEVEL='*' $LOGGER "Setting up alternatives for Node.js $DOWNLOAD_VERSION..."
node="$INSTALL_PREFIX/node-$DOWNLOAD_VERSION/bin/node"
[ ! -L "\$node" ] || node="\$(readlink -f \$node)"
update-alternatives --install "$NODEJS_HOME/bin/node" node "\$node" 1
npm="$INSTALL_PREFIX/node-$DOWNLOAD_VERSION/bin/npm"
[ ! -L "\$npm" ] || npm="\$(readlink -f \$npm)"
update-alternatives --install "$NODEJS_HOME/bin/npm" npm "\$npm" 1
npx="$INSTALL_PREFIX/node-$DOWNLOAD_VERSION/bin/npx"
[ ! -L "\$npx" ] || npx="\$(readlink -f \$npx)"
update-alternatives --install "$NODEJS_HOME/bin/npx" npx "\$npx" 1
EOF

else
    LEVEL='!' $LOGGER "Failed to download $TOOL_LABEL from $DOWNLOAD_URL"
    exit 1
fi

$LOGGER "Done! $TOOL_LABEL installation complete."
