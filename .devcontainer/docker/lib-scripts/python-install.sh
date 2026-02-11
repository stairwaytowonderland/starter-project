#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"
PYTHON_INSTALL_PATH="${PYTHON_INSTALL_PATH:-"/usr/local/python"}"

# shellcheck disable=SC1091
. /helpers/install-helper.sh

LEVEL='ƒ' $LOGGER "Installing Python utilities..."

install_cpython() {
    VERSION=${1:-$VERSION}
    INSTALL_PATH="${PYTHON_INSTALL_PATH}/${VERSION}"

    # Check if the specified Python version is already installed
    if [ -d "${INSTALL_PATH}" ]; then
        LEVEL='!' $LOGGER "Requested Python version ${VERSION} already installed at ${INSTALL_PATH}."
    else
        # * NOTE: pkg-config required to build Python from source
        # * NOTE: xz-utils required to decompress .tar.xz files
        PACKAGES_TO_INSTALL="$(
            cat << EOF
libbz2-dev
libffi-dev
libgdbm-dev
liblzma-dev
libncurses5-dev
libreadline-dev
libsqlite3-dev
libxml2-dev
libxmlsec1-dev
tk-dev
pkg-config
xz-utils
EOF
        )"

        update_and_install "${PACKAGES_TO_INSTALL# }"
        mkdir -p "${INSTALL_PATH}"
        tmpdir="$(mktemp -d)"
        cd "${tmpdir}"
        cpython_xz_filename="Python-${VERSION}.tar.xz"
        cpython_xz_url="https://www.python.org/ftp/python/${VERSION}/${cpython_xz_filename}"
        echo "Downloading ${cpython_xz_filename}..."
        (
            set -x
            curl -sSL "${cpython_xz_url}" | tar -xJC "${tmpdir}" --strip-components=1 --no-same-owner
        )
        ./configure --prefix="${INSTALL_PATH}" --with-ensurepip=install
        make -j 8
        make install
        cd /tmp
        rm -rf "${tmpdir}"
        remove_packages "${PACKAGES_TO_INSTALL# }"
    fi
}

if [ "$PYTHON_VERSION" = "system" ] \
    || { ! type "$BREW" > /dev/null 2>&1 && [ "$PYTHON_VERSION" = "latest" ]; }; then

    if [ "$PYTHON_VERSION" = "latest" ]; then
        __find_version_from_git_tags "python/cpython" "latest" "tags/v" "." \
            && PYTHON_VERSION="${VERSION}"

        if python3 --version | grep -q "Python ${PYTHON_VERSION%%.*}"; then
            LEVEL='!' $LOGGER "Requested Python version ${PYTHON_VERSION} already installed."
        fi

        if [ "$IMAGE_NAME" = "ubuntu" ] && [ "$USE_PPA_IF_AVAILABLE" = "true" ]; then
            PACKAGES_TO_INSTALL="$(
                cat << EOF
python3.14
python3.14-venv
python3.14-dev
pipx
EOF
            )"

            add-apt-repository ppa:deadsnakes/ppa -y
            update_and_install "${PACKAGES_TO_INSTALL# }"

            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 2
        fi
    fi

    if [ -z "$PACKAGES_TO_INSTALL" ] && [ "$PYTHON_VERSION" = "latest" ]; then
        PACKAGES_TO_INSTALL="$(
            cat << EOF
python3
python3-pip
python3-venv
python3-dev
pipx
EOF
        )"
        install_packages "${PACKAGES_TO_INSTALL# }"
    fi
fi

LEVEL='√' $LOGGER "Done! Python utilities installation complete."

# export PYTHON_DEFAULT_VERSION=$(python3 --version | awk '{print $2}' | awk -F'.' '{print $1"."$2}') && \
# apt-get --assume-yes --quiet update && \
# DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install software-properties-common && \
# add-apt-repository -y 'ppa:deadsnakes/ppa' && \
# { [ "${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" != "${PYTHON_DEFAULT_VERSION}" ] && \
#     DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install "python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" "python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}-distutils" && \
#     update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${PYTHON_DEFAULT_VERSION}" 99 && \
#     update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" 98 && \
#     update-alternatives --set python3 $(update-alternatives --list python3 | grep "python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}") && \
#     python${AWS_PYTHON_LAMBDA_RUNTIME_VERSION} -m pip install $PIP_PKGS --no-cache-dir; } && \
# # python${PYTHON_DEFAULT_VERSION} -m pip install $PIP_PKGS --no-cache-dir && \
# priority=0 && \
# { for python_version in $(echo $ADDITIONAL_PYTHON_VERSIONS); do \
#     [ "${python_version}" != "${PYTHON_DEFAULT_VERSION}" -a "${python_version}" != "${AWS_PYTHON_LAMBDA_RUNTIME_VERSION}" ] && \
#         priority=$((priority+1)) && \
#         DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install "python${python_version}" "python${python_version}-distutils" && \
#         update-alternatives --install /usr/bin/python3 python3 "/usr/bin/python${python_version}" $priority && \
#         python${python_version} -m pip install $PIP_PKGS --no-cache-dir; \
# done; } && \
# DEBIAN_FRONTEND=noninteractive apt-get --assume-yes --quiet install python-is-python3 && \
# rm --recursive --force /var/lib/apt/lists/* && \
# pip cache purge
