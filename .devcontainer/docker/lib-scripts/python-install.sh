#!/bin/sh

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"
PYTHON_INSTALL_PATH="${PYTHON_INSTALL_PATH:-"/usr/local/python"}"
VERSION="${PYTHON_VERSION:-latest}"

# shellcheck disable=SC1091
. /helpers/install-helper.sh

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

check_current_version() {
    __python_version=$("python${2:-3}" --version)
    if "python${2:-3}" --version | grep -q "Python ${1}"; then
        LEVEL='!' $LOGGER "Requested Python version ${1} already installed."
    fi
    printf '%s\n' "${__python_version#* }"
}

updaterc() {
    case "$(cat /etc/bash.bashrc)" in
        *"$1"*) ;;
        *) printf '\n%s\n' "$1" >> /etc/bash.bashrc ;;
    esac
}

get_alternatives_priority() {
    { update-alternatives --display "${1}${2-}" 2> /dev/null || echo "priority -1"; } | awk '/priority/ {print $NF}' | sort -n | head -n 1
}

update_alternatives() {
    if type "${1}${2}" > /dev/null 2>&1; then
        update-alternatives --install "${3:-$PYTHON_INSTALL_PATH}/bin/${1}${2%%.*}" "${1}${2%%.*}" "$(command -v "${1}${2}")" $(($(get_alternatives_priority "${1}" "${2%%.*}") + 1))
        update-alternatives --install "${3:-$PYTHON_INSTALL_PATH}/bin/${1}" "${1}" "$(command -v "${1}${2}")" $(($(get_alternatives_priority "${1}") + 1))
    fi
}

PYTHON_VERSION="$VERSION"

if [ "$PYTHON_VERSION" != "system" ] \
    && [ "$PYTHON_VERSION" != "none" ] \
    && [ "$PYTHON_VERSION" != "devcontainer" ]; then

    PACKAGE_CLEANUP="${PACKAGE_CLEANUP:-true}"
    BUILD_CLEANUP="${BUILD_CLEANUP:-true}"

    LEVEL='ƒ' $LOGGER "Installing Python utilities..."

    ESSENTIAL_PACKAGES="${ESSENTIAL_PACKAGES% } $(
        cat << EOF
git
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

    for pkg in $ESSENTIAL_PACKAGES; do
        if ! dpkg -s "$pkg" > /dev/null 2>&1; then
            PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $pkg"
        fi
    done

    update_and_install "${PACKAGES_TO_INSTALL# }"

    __find_version_from_git_tags "python/cpython" "${PYTHON_VERSION}" "tags/v" "." \
        && PYTHON_VERSION="${VERSION}"

    major_version="$(get_major_version "$PYTHON_VERSION")"

    current_version="$(check_current_version "$PYTHON_VERSION" "$major_version")"

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

get_alternatives_priority() {
    { update-alternatives --display "\${1}\${2}" 2> /dev/null || echo "priority -1"; } | awk '/priority/ {print \$NF}' | sort -n | head -n 1
}

for py in python pip idle pydoc python-config; do
    [ -L "\${INSTALL_PATH}/bin/\${py}" ] || ln -s "\${INSTALL_PATH}/bin/\${py}${major_version}" "\${INSTALL_PATH}/bin/\${py}"
done

# updaterc "if [[ \"\${PATH}\" != *\"\${INSTALL_PATH}/bin\"* ]]; then export \"PATH=\${INSTALL_PATH}/bin:\${PATH}\"; fi"

for py in python pip idle pydoc; do
    priority=\$((\$(get_alternatives_priority "\$py" "\$major_version") + 1))
    [ "\$priority" -ge 0 ] || priority=\$((priority + 1))
    syspy="\$(readlink -f "${SYSTEM_PYTHON%/bin/python*}/bin/\${py}${major_version}")"
    [ ! -x "\$syspy" ] || update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}${major_version}" "\${py}${major_version}" "\$syspy" "\$priority" && priority="\$((priority + 1))"
    {
        update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}" "\${py}" "${INSTALL_PATH}/bin/\${py}" "\$priority";
        update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}${major_version}" "\${py}${major_version}" "${INSTALL_PATH}/bin/\${py}${major_version}" "\$priority";
    } && priority="\$((priority + 1))"
done
for py in python-config python${major_version}-config; do
    syspy="\$(readlink -f "${SYSTEM_PYTHON%/bin/python*}/bin/\${py}")"
    priority=\$((\$(get_alternatives_priority "\$py") + 1))
    [ "\$priority" -ge 0 ] || priority=\$((priority + 1))
    [ ! -x "\$syspy" ] || update-alternatives --install "\${ALTERNATIVES_PATH}/\${py}" "\${py}" "\$syspy" "\$priority" && priority="\$((priority + 1))"
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

elif [ "$PYTHON_VERSION" = "system" ]; then

    type git > /dev/null 2>&1 || update_and_install git

    __find_version_from_git_tags "python/cpython" "latest" "tags/v" "." \
        && PYTHON_VERSION="${VERSION}"

    major_version="${PYTHON_VERSION%%.*}"
    major_minor_version="${PYTHON_VERSION%.*}"

    current_version="$(check_current_version "$PYTHON_VERSION" "$major_version")"
    current_major_minor_version="${current_version%.*}"

    mkdir -p "${PYTHON_INSTALL_PATH}/bin"
    update_alternatives python "$current_major_minor_version" "${PYTHON_INSTALL_PATH}"

    if [ "$IMAGE_NAME" = "ubuntu" ] && [ "$USE_PPA_IF_AVAILABLE" = "true" ]; then

        LEVEL='*' $LOGGER "Preparing to install Python version ${major_minor_version} to ${INSTALL_PATH}..."

        PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
            cat << EOF
python${major_minor_version}
python${major_minor_version}-venv
python${major_minor_version}-dev
pipx
EOF
        )"

        add-apt-repository ppa:deadsnakes/ppa -y
        update_and_install "${PACKAGES_TO_INSTALL# }"

        update_alternatives python "$major_minor_version" "${PYTHON_INSTALL_PATH}"

        updaterc "if [[ \"\${PATH}\" != *\"${PYTHON_INSTALL_PATH}/bin\"* ]]; then export \"PATH=${PYTHON_INSTALL_PATH}/bin:\${PATH}\"; fi"
    else
        LEVEL='*' $LOGGER "Preparing to install Python version ${major_version} to ${INSTALL_PATH}..."

        PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% } $(
            cat << EOF
python${major_version}
python${major_version}-pip
python${major_version}-venv
python${major_version}-dev
pipx
EOF
        )"

        update_and_install "${PACKAGES_TO_INSTALL# }"

        update_alternatives python "$major_version" "${PYTHON_INSTALL_PATH}"

        updaterc "if [[ \"\${PATH}\" != *\"${PYTHON_INSTALL_PATH}/bin\"* ]]; then export \"PATH=${PYTHON_INSTALL_PATH}/bin:\${PATH}\"; fi"
    fi

    LEVEL='√' $LOGGER "Done! Python utilities installation complete."
fi
