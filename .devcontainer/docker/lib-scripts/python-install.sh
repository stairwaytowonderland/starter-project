#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"
PYTHON_INSTALL_PATH="${PYTHON_INSTALL_PATH:-"/usr/local/python"}"
VERSION="${PYTHON_VERSION:-latest}"
PACKAGE_CLEANUP="${PACKAGE_CLEANUP:-true}"
BUILD_CLEANUP="${BUILD_CLEANUP:-true}"

# shellcheck disable=SC1091
. /helpers/install-helper.sh

# LEVEL='ƒ' $LOGGER "Installing Python utilities..."

PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
    cat << EOF
gcc
xz-utils
EOF
)"

PYTHON_BUILD_DEPENDENCIES="${PYTHON_BUILD_DEPENDENCIES% } $(
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
EOF
)"

download_cpython_version() {
    LEVEL='*' $LOGGER "Downloading Python version ${1}..."

    cd /tmp
    cpython_download_prefix="Python-${1}"
    if type xz > /dev/null 2>&1; then
        cpython_download_filename="${cpython_download_prefix}.tar.xz"
    elif type gzip > /dev/null 2>&1; then
        cpython_download_filename="${cpython_download_prefix}.tgz"
    else
        LEVEL='error' $LOGGER "Required package (xz-utils or gzip) not found."
        return 1
    fi

    DOWNLOAD_URL="https://www.python.org/ftp/python/${1}/${cpython_download_filename}"

    __install_from_tarball "$DOWNLOAD_URL" "$PWD" && DOWNLOAD_DIR="${PWD}/${cpython_download_prefix}"
}

install_cpython() {
    VERSION=${1:-$VERSION}
    INSTALL_PATH="${PYTHON_INSTALL_PATH}/${VERSION}"

    LEVEL='*' $LOGGER "Preparing to install Python version ${VERSION} to ${INSTALL_PATH}..."

    # Check if the specified Python version is already installed
    if [ -d "$INSTALL_PATH" ]; then
        LEVEL='!' $LOGGER "Requested Python version ${VERSION} already installed at ${INSTALL_PATH}."
    else
        cwd="$PWD"
        mkdir -p "$INSTALL_PATH"
        download_cpython_version "${VERSION}"
        if [ -d "$DOWNLOAD_DIR" ]; then
            cd "$DOWNLOAD_DIR"
        else
            LEVEL='error' $LOGGER "Failed to download Python version ${VERSION}."
            exit 1
        fi
        install_packages "${PYTHON_BUILD_DEPENDENCIES# }"
        ./configure --prefix="$INSTALL_PATH" --with-ensurepip=install
        make -j 8
        make install
        cd "$cwd" && rm -rf "$DOWNLOAD_DIR"

        # Cleanup
        remove_packages "${PYTHON_BUILD_DEPENDENCIES# }"

        # Strip unnecessary files to reduce image size
        if [ "$BUILD_CLEANUP" = "true" ]; then
            find "$INSTALL_PATH" -type d -name 'test' -exec rm -rf {} + 2> /dev/null || true
            find "$INSTALL_PATH" -type d -name '__pycache__' -exec rm -rf {} + 2> /dev/null || true
            find "$INSTALL_PATH" -name '*.pyc' -delete
            find "$INSTALL_PATH" -name '*.pyo' -delete
            rm -rf "$INSTALL_PATH"/lib/python*/config-*
            rm -rf "$INSTALL_PATH"/lib/*.a
        fi
    fi
}

if [ "$VERSION" != "system" ] \
    && [ "$VERSION" != "none" ] \
    && [ "$VERSION" != "devcontainer" ]; then

    LEVEL='ƒ' $LOGGER "Installing Python utilities..."

    update_and_install "${PACKAGES_TO_INSTALL# }" git

    __find_version_from_git_tags "python/cpython" "${VERSION}" "tags/v" "." \
        && PYTHON_VERSION="${VERSION}"

    major_version="$(get_major_version "$PYTHON_VERSION")"

    if "python${major_version}" --version | grep -q "Python ${PYTHON_VERSION%%.*}"; then
        LEVEL='!' $LOGGER "Requested Python version ${PYTHON_VERSION} already installed."
    fi

    install_cpython "$PYTHON_VERSION"

    remove_packages "${PACKAGES_TO_INSTALL# }"

    # Remove system pre-commit to avoid conflicts with pipx installation
    if [ "$PRE_COMMIT_ENABLED" = "true" ] && type pre-commit > /dev/null 2>&1; then
        apt-get -y remove pre-commit || true
    fi

    SYSTEM_PYTHON="$(command -v "/usr/bin/python${major_version}" || true)"
    PYTHON_SRC_ACTUAL="${INSTALL_PATH}/bin/python${PYTHON_VERSION%.*}"
    PYTHON_SRC="${INSTALL_PATH}/bin/python${major_version}"
    PATH="${INSTALL_PATH}/bin:${PATH}"

    cat >> "${PYTHON_INSTALL_PATH}/.manifest" << EOF
{"path":"${PYTHON_SRC_ACTUAL}","url":"${DOWNLOAD_URL}","version":"${PYTHON_VERSION}"}
EOF

    # shellcheck disable=SC2154
    touch "${PYTHON_INSTALL_PATH}/python-${PYTHON_VERSION}-config" \
        && chmod +x "${PYTHON_INSTALL_PATH}/python-${PYTHON_VERSION}-config" \
        && cat > "${PYTHON_INSTALL_PATH}/python-${PYTHON_VERSION}-config" << EOF
#!/bin/sh
set -e

LEVEL='*' $LOGGER "Setting up alternatives for Python ${PYTHON_VERSION}..."

VERSION="$PYTHON_VERSION"
PYTHON_INSTALL_PATH="\${PYTHON_INSTALL_PATH:-$PYTHON_INSTALL_PATH}"
INSTALL_PATH="\${INSTALL_PATH:-\${PYTHON_INSTALL_PATH}/\${VERSION}}"
ALTERNATIVES_PATH="\${ALTERNATIVES_PATH:-/usr/local/bin}"

updaterc() {
    case "\$(cat /etc/bash.bashrc)" in
        *"\$1"*) ;;
        *) printf '\n%s\n' "\$1" >> /etc/bash.bashrc ;;
    esac
}

for py in python pip idle pydoc python-config; do
    [ -L "\${INSTALL_PATH}/bin/\${py}" ] || ln -s "\${INSTALL_PATH}/bin/\${py}${major_version}" "\${INSTALL_PATH}/bin/\${py}"
done

# updaterc "if [[ \"\${PATH}\" != *\"\${INSTALL_PATH}/bin\"* ]]; then export PATH=\${INSTALL_PATH}/bin:\${PATH}; fi"

for py in python pip idle pydoc; do
    priority=0
    syspy="\$(readlink -f "${SYSTEM_PYTHON%/bin/python*}/bin/\${py}${major_version}")"
    [ -x "\$syspy" ] && update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}${major_version}" "\${py}${major_version}" "\$syspy" "\$priority" && priority="\$((priority + 1))"
    {
        update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}" "\${py}" "${INSTALL_PATH}/bin/\${py}" "\$priority";
        update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}${major_version}" "\${py}${major_version}" "${INSTALL_PATH}/bin/\${py}${major_version}" "\$priority";
    } && priority="\$((priority + 1))"
done
for py in python-config python${major_version}-config; do
    syspy="\$(readlink -f "${SYSTEM_PYTHON%/bin/python*}/bin/\${py}")"
    priority=0
    [ -x "\$syspy" ] && update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}" "\${py}" "\$syspy" "\$priority" && priority="\$((priority + 1))"
    update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}" "\${py}" "${INSTALL_PATH}/bin/\${py}" "\$priority" && priority="\$((priority + 1))"
done
EOF

    touch "${PYTHON_INSTALL_PATH}/python-${PYTHON_VERSION}-tools" \
        && chmod +x "${PYTHON_INSTALL_PATH}/python-${PYTHON_VERSION}-tools" \
        && cat > "${PYTHON_INSTALL_PATH}/python-${PYTHON_VERSION}-tools" << EOF
#!/bin/sh
set -e

LEVEL='*' $LOGGER "Installing Python tools for Python ${PYTHON_VERSION}..."

VERSION="$PYTHON_VERSION"
PYTHON_INSTALL_PATH="\${PYTHON_INSTALL_PATH:-$PYTHON_INSTALL_PATH}"

if [ "\$(id -u)" -eq 0 ]; then
    LEVEL='error' $LOGGER "Unable to install Python tools (pipx, pre-commit, poetry, uv) as root user."
    return 1
fi
if [ -x "${PYTHON_SRC}" ]; then
    "\${PYTHON_INSTALL_PATH}/\${VERSION}/bin/python${major_version}" -m pip install --no-cache-dir --upgrade pip
    "\${PYTHON_INSTALL_PATH}/\${VERSION}/bin/pip${major_version}" install --disable-pip-version-check --no-cache-dir --user pipx 2>&1
fi
for tool in pre-commit poetry uv; do
    if "$PIPX" > /dev/null 2>&1; then
        if [ "\$tool" = "pre-commit" ] && [ "$PRE_COMMIT_ENABLED" = "true" ]; then
=           $("$PIPX") install "\$tool"
        elif [ "\$tool" != "pre-commit" ]; then
            type "\$tool" > /dev/null 2>&1 || $("$PIPX") install "\$tool"
        fi
    fi
done
EOF

    LEVEL='√' $LOGGER "Done! Python utilities installation complete."
fi

# if [ "$PYTHON_VERSION" = "system" ] \
#     || { ! type "$BREW" > /dev/null 2>&1 && [ "$PYTHON_VERSION" = "latest" ]; }; then

#     if [ "$PYTHON_VERSION" = "latest" ]; then
#         __find_version_from_git_tags "python/cpython" "latest" "tags/v" "." \
#             && PYTHON_VERSION="${VERSION}"

#         if python3 --version | grep -q "Python ${PYTHON_VERSION%%.*}"; then
#             LEVEL='!' $LOGGER "Requested Python version ${PYTHON_VERSION} already installed."
#         fi

#         if [ "$IMAGE_NAME" = "ubuntu" ] && [ "$USE_PPA_IF_AVAILABLE" = "true" ]; then
#             PACKAGES_TO_INSTALL="$(
#                 cat << EOF
# python3.14
# python3.14-venv
# python3.14-dev
# pipx
# EOF
#             )"

#             add-apt-repository ppa:deadsnakes/ppa -y
#             update_and_install "${PACKAGES_TO_INSTALL# }"

#             update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
#             update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 2
#         fi
#     fi

#     if [ -z "$PACKAGES_TO_INSTALL" ] && [ "$PYTHON_VERSION" = "latest" ]; then
#         PACKAGES_TO_INSTALL="$(
#             cat << EOF
# python3
# python3-pip
# python3-venv
# python3-dev
# pipx
# EOF
#         )"
#         install_packages "${PACKAGES_TO_INSTALL# }"
#     fi
# fi

# LEVEL='√' $LOGGER "Done! Python utilities installation complete."
