#!/bin/sh

# * All variables are expected to be set via build args in the Dockerfile

set -e

USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"

$LOGGER "Installing devtools utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

install_packages() {
    # shellcheck disable=SC2086
    $LOGGER "Installing the following packages: "$*
    # shellcheck disable=SC2086,SC2048
    apt-get -y install --no-install-recommends $*
}

update_and_install() {
    apt-get update
    install_packages "$@"
}

PACKAGES_TO_INSTALL="$(
    cat << EOF
tar
make
gnupg
EOF
)"

# ! CAUTION: Homebrew recommends `build-essential`, which is large,
# ! and has a non-fixable high cve (as of January 2026); Install only if needed.
# ! The reason is that many formulae require compilation during installation.
# ! For the same reason, if compiling Python from source, we need it too.
# Installing build-essential in this image as a convenience (this image is meant for development use anyway)
if [ "$HOMEBREW_ENABLED" = "true" ]; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
        cat << EOF
 build-essential
EOF
    )"
fi

if [ "$PYTHON_VERSION" = "system" ] \
    || { [ "$HOMEBREW_ENABLED" != "true" ] \
        && [ "$PYTHON_VERSION" = "latest" ]; }; then

    if [ "$PYTHON_VERSION" = "latest" ]; then
        if [ "$IMAGE_NAME" = "ubuntu" ] && [ "$USE_PPA_IF_AVAILABLE" = "true" ]; then
            PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
                cat << EOF
python3.14
python3.14-venv
python3.14-dev
pipx
EOF
            )"

            add-apt-repository ppa:deadsnakes/ppa -y
            update_and_install "$PACKAGES_TO_INSTALL"

            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 2
        fi
    else

        # curl -sS https://bootstrap.pypa.io/get-pip.py | python3.14
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $(
            cat << EOF
python3-venv
python3-dev
pipx
EOF
        )"
    fi
fi

# Install Node.js (LTS version) and npm
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && PACKAGES_TO_INSTALL="$(
        cat << EOF
nodejs
EOF
    )" \
    && $LOGGER "Node.js and npm packages: $PACKAGES_TO_INSTALL" \
    && install_packages "$PACKAGES_TO_INSTALL"

# shellcheck disable=SC2016  # Don't want variables expanded in the echo 'eval ...' line
# [ -d /etc/apt/keyrings ] || { mkdir -p 755 /etc/apt/keyrings && chown 755 /etc/apt/keyrings; } \
#     && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
#     && cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
#     && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
#     && mkdir -p /etc/apt/sources.list.d \
#         && chmod 755 /etc/apt/sources.list.d \
#     && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
#         | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
#     && apt-get update \
#         && apt-get -y install --no-install-recommends gh \
#     && echo >> "/home/$USERNAME/.bashrc" \
#     && echo 'eval "$(gh completion -s bash)"' >> "/home/$USERNAME/.bashrc" \
#     && rm -f "$out"

$LOGGER "Done! Devtools utilities installation complete."
