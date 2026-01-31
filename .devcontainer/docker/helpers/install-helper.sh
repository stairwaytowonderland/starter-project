#!/bin/sh

VERSION="${VERSION:-latest}"

export DEBIAN_FRONTEND=noninteractive

__get_platform() {
    PLATFORM="$(uname -sm | tr '[:upper:]' '[:lower:]')"
    echo "$PLATFORM"
}

__get_os() {
    _platform="${1:-$(__get_platform)}"
    _platform_os="${_platform%% *}"
    case "$_platform_os" in
        linux)
            _download_os=linux
            ;;
        darwin)
            _download_os=darwin
            ;;
        *)
            LEVEL=error $LOGGER "Unsupported OS: $_platform_os"
            return 1
            ;;
    esac

    echo "$_download_os"
}

__get_arch() {
    _platform="${1:-$(__get_platform)}"
    _platform_arch="${_platform##* }"
    case "$_platform_arch" in
        x86_64)
            _download_arch=amd64
            ;;
        aarch64)
            _download_arch=arm64
            ;;
        *)
            LEVEL=error $LOGGER "Unsupported architecture: $_download_arch"
            return 1
            ;;
    esac

    echo "$_download_arch"
}

install_packages() {
    # shellcheck disable=SC2086
    LEVEL='ƒ' $LOGGER "Installing the following packages: "$*
    # shellcheck disable=SC2086,SC2048
    apt-get -y install --no-install-recommends $*
}

update_and_install() {
    apt-get update
    install_packages "$@"
}

# Usage example for defining packages to install:
#
# PACKAGES_TO_INSTALL="${PACKAGES_TO_INSTALL% }$(
#     cat << EOF
# list
# of
# packages
# EOF
# )"
#
# [ -z "$PACKAGES_TO_INSTALL" ] \
#     && update_and_install "$PACKAGES_TO_INSTALL" \
#     || echo "Warning: No packages to install."

__check_semver() {
    _version="${1-}"

    [ "$(echo "${_version}" | grep -o '\.' | wc -l)" = "2" ] || return 1
}

__get_version() {
    _github_repo="${1-}"
    _version="${2:-latest}"

    if [ -z "$_github_repo" ]; then
        LEVEL='error' $LOGGER "GitHub repository is required to fetch version (${_version}) from tags."
        return 1
    fi

    if [ ! "$(__check_semver "$_version")" ]; then
        # https://github.com/devcontainers/features/blob/main/src/git/install.sh#L291C76-L291C117
        version_list="$(curl -sSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/${_github_repo}/tags" | grep -oP '"name":\s*"v\K[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -rV)"
        if [ "${_version}" = "latest" ] || [ "${_version}" = "lts" ] || [ "${_version}" = "current" ]; then
            VERSION="$(echo "${version_list}" | head -n 1)"
        else
            escaped_version="$(echo "${_version}" | sed 's/\./\\./g')"
            VERSION="$(echo "${version_list}" | grep -E -m 1 "^${escaped_version}([\\.\\s]|$)")"
        fi
        escaped_version_check="$(echo "${VERSION}" | sed 's/\./\\./g')"
        if [ -z "${VERSION}" ] || ! echo "${version_list}" | grep "^${escaped_version_check}$" > /dev/null 2>&1; then
            LEVEL='error' $LOGGER "Invalid git version: ${VERSION}"
            return 2
        fi
    fi

    # shellcheck disable=SC2015
    __check_semver "$VERSION" && echo "$VERSION" || {
        LEVEL='error' $LOGGER "Version must be a semantic version (e.g., 1.2.3): ${VERSION}"
        return 3
    }
}

__set_url_parts() {
    _github_repo="${1-}"
    _version="${2-}"

    if [ $# -gt 3 ]; then
        _version_prefix="${3-}"
        _url_prefix="${4%"$_version_prefix"}"
        DOWNLOAD_URL_PREFIX="${_url_prefix%/}"
    else
        _url_prefix="${3-}"
        _version_prefix=""
        DOWNLOAD_URL_PREFIX="${_url_prefix}"
    fi

    _download_version="$(__get_version "$_github_repo" "$_version")" || return $?
    DOWNLOAD_VERSION="${_version_prefix}${_download_version#"$_version_prefix"}"
    DOWNLOAD_PLATFORM="$(uname -sm | tr '[:upper:]' '[:lower:]')"
    DOWNLOAD_OS="$(__get_os "$DOWNLOAD_PLATFORM")" || return $?
    DOWNLOAD_ARCH="$(__get_arch "$DOWNLOAD_PLATFORM")" || return $?
}

__install_from_tarball() {
    DOWNLOAD_URL="${1-}"
    INSTALL_PREFIX="${2-"/usr/local"}"
    file_ext="${DOWNLOAD_URL##*.}"
    case "$file_ext" in
        gz | tgz)
            tar_opts="z"
            ;;
        xz)
            tar_opts="J"
            ;;
        bz2 | bz)
            tar_opts="j"
            ;;
        *)
            LEVEL='error' $LOGGER "Unsupported tarball extension: $file_ext"
            return 1
            ;;
    esac

    mkdir -p "$INSTALL_PREFIX"
    LEVEL='*' $LOGGER "Downloading from $DOWNLOAD_URL ..."
    (
        set -x
        curl -fsSL "$DOWNLOAD_URL" | tar -C "$INSTALL_PREFIX" -"xv${tar_opts}f" -
    )
}

__install_from_package() {
    DOWNLOAD_URL="${1-}"
    file_ext="${DOWNLOAD_URL##*.}"
    [ "$file_ext" = "deb" ] || {
        LEVEL='error' $LOGGER "Unsupported package extension: $file_ext"
        return 1
    }

    LEVEL='*' $LOGGER "Downloading from $DOWNLOAD_URL ..."
    (
        set -x
        curl -fsOSL "$DOWNLOAD_URL" \
            && dpkg -i "${DOWNLOAD_URL##*/}" \
            && rm -f "${DOWNLOAD_URL##*/}"
    )
}

export DOWNLOAD_VERSION DOWNLOAD_PLATFORM DOWNLOAD_OS DOWNLOAD_ARCH DOWNLOAD_URL_PREFIX

# Usage example for downloading and installing from a tarball:
#
# # Include install-helper.sh
# . install-helper.sh
#
# main() {
#     if __set_url_parts "owner/repo" "$VERSION"; then
#         build_url() {
#             url_prefix="https://github.com/owner/repo/releases/download/v"
#             echo "${url_prefix}${DOWNLOAD_VERSION}/file-name-${DOWNLOAD_VERSION}-${DOWNLOAD_OS}-${DOWNLOAD_ARCH}.tar.gz"
#         }
#         DOWNLOAD_URL="$(build_url)"
#     else
#         $LOGGER "Failed to determine download parameters for owner/repo version $VERSION"
#         exit 1
#     fi
#     __install_from_tarball "$DOWNLOAD_URL"
# }
