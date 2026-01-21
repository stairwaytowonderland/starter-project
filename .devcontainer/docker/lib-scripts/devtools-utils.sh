#!/bin/sh

# * All variables are expected to be set via build args in the Dockerfile

set -e

$LOGGER "Installing devtools utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

PACKAGES_TO_INSTALL="$(
    cat << EOF
tar
make
gnupg
EOF
)"

if [ "$PYTHON_VERSION" = "system" ] \
    || { [ "$HOMEBREW_ENABLED" != "true" ] \
        && [ "$PYTHON_VERSION" = "latest" ]; }; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
        cat << EOF
python3-pip
python3-venv
python3-dev
pipx
EOF
    )"
fi

# ! CAUTION: Homebrew recommends `build-essential`, which is large,
# ! and has a non-fixable high cve (as of January 2026); Install only if needed
# Installing build-essential in this image as a convenience (this image is meant for development use anyway)
if [ "$HOMEBREW_ENABLED" = "true" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
        cat << EOF
 build-essential
EOF
    )"
fi

# shellcheck disable=SC2086
$LOGGER "Installing the following packages: "$PACKAGES_TO_INSTALL

# shellcheck disable=SC2086
apt-get -y install --no-install-recommends $PACKAGES_TO_INSTALL

# Install Node.js (LTS version) and npm
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get -y install --no-install-recommends nodejs

# shellcheck disable=SC2016  # Don't want variables expanded in the echo 'eval ...' line
[ -d /etc/apt/keyrings ] || { mkdir -p 755 /etc/apt/keyrings && chown 755 /etc/apt/keyrings; } \
    && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p /etc/apt/sources.list.d \
        && chmod 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
        && apt-get -y install --no-install-recommends gh \
    && echo >> "/home/$USERNAME/.bashrc" \
    && echo 'eval "$(gh completion -s bash)"' >> "/home/$USERNAME/.bashrc" \
    && rm -f "$out"

$LOGGER "Done! Devtools utilities installation complete."
