#!/usr/bin/env bash

# ! NOTE: Installing GIT from source causes issues for the gh CLI dev container feature

set -e

GIT_VERSION="${GIT_VERSION:-latest}"
USE_PPA_IF_AVAILABLE="${USE_PPA_IF_AVAILABLE:-true}"
SOURCE_AS_FALLBACK="${SOURCE_AS_FALLBACK:-false}"

apt-get update

export DEBIAN_FRONTEND=noninteractive

# * If installing from source, GIT_VERSION needs to be reset to the actual version
# being built, since the Makefile uses it. We could also avoid using GIT_VERSION
# as a global variable, but resetting the variable for the build is simpler.
get_version() {
    local git_version="${1:-$GIT_VERSION}"

    if [ "$(echo "${git_version}" | grep -o '\.' | wc -l)" != "2" ]; then
        version_list="$(curl -sSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/git/git/tags" | grep -oP '"name":\s*"v\K[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -rV)"
        if [ "${git_version}" = "latest" ] || [ "${git_version}" = "lts" ] || [ "${git_version}" = "current" ]; then
            GIT_VERSION="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            GIT_VERSION="$(echo "${version_list}" | grep -E -m 1 "^${git_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
        if [ -z "${GIT_VERSION}" ] || ! echo "${version_list}" | grep "^${GIT_VERSION//./\\.}$" > /dev/null 2>&1; then
            LEVEL=error $LOGGER "Invalid git version: ${GIT_VERSION}"
            exit 1
        fi
    fi
}

git_download() {
    local git_version="${1:-$GIT_VERSION}"
    local git_tar="git-${git_version}.tar.gz"
    local git_url="https://www.kernel.org/pub/software/scm/git/${git_tar}"
    # shellcheck disable=SC2034  # Unused variables left for readability
    local git_url_mirror1="https://mirrors.edge.kernel.org/pub/software/scm/git/git-${git_version}.tar.gz"
    # shellcheck disable=SC2034  # Unused variables left for readability
    local git_url_mirror2="https://github.com/git/git/archive/v${git_version}.tar.gz"
    $LOGGER "Downloading source for git version ${git_version}..."
    (
        set -x
        # curl -sSL -o "/tmp/${git_tar}" "${git_url}" | tar -xzC /tmp
        curl -sSL -o "/tmp/${git_tar}" "${git_url}"
        tar -xzf "/tmp/${git_tar}" -C /tmp/
    )
}

git_build() {
    local git_version="${1:-$GIT_VERSION}"
    $LOGGER "Building git version ${git_version}..."
    # cd "/tmp/git-${git_version}"
    # ./configure --prefix=/usr/local
    # make all
    # make install
    make -C "/tmp/git-${git_version}" prefix=/usr/local sysconfdir=/etc all
    make -C "/tmp/git-${git_version}" prefix=/usr/local sysconfdir=/etc install
    update-alternatives --install /usr/bin/git git /usr/local/bin/git 1
}

git_install() {
    local git_version="$1"

    if { [ "${git_version}" = "latest" ] || [ "${git_version}" = "lts" ] || [ "${git_version}" = "current" ]; } \
        && [ "${IMAGE_NAME}" = "ubuntu" ] && [ "${USE_PPA_IF_AVAILABLE}" = "true" ]; then
            # Remove any existing git installation
            apt-get -y remove git

            apt-get -y install --no-install-recommends git-core
            add-apt-repository ppa:git-core/ppa \
                && apt-get update \
                && apt-get -y install --no-install-recommends git
        $LOGGER "Done! GIT installation from PPA complete!"
    else
        if [ "${SOURCE_AS_FALLBACK}" = "true" ]; then
            # Remove any existing git installation
            apt-get -y remove git

            # Install build dependencies
            # https://git-scm.com/book/en/v2/Getting-Started-Installing-Git#_installing_from_source
            apt-get -y install --no-install-recommends \
                dh-autoreconf libcurl4-gnutls-dev libexpat1-dev \
                gettext libz-dev libssl-dev \
                install-info

            get_version "${git_version}"
            git_download
            git_build
            rm -f "/tmp/git-${GIT_VERSION}.tar.gz"
            rm -rf "/tmp/git-${GIT_VERSION}"
            $LOGGER "Done! GIT installation from source complete!"

            # Remove build dependencies
            apt-get -y remove \
                dh-autoreconf libcurl4-gnutls-dev libexpat1-dev \
                gettext libz-dev libssl-dev \
                install-info
        fi
    fi

    if ! type git > /dev/null 2>&1; then
        apt-get -y install --no-install-recommends git
        $LOGGER "Done! GIT installation from apt complete!"
    fi
}

git_install "$GIT_VERSION"

if ! type git > /dev/null 2>&1; then
    LEVEL=error $LOGGER "GIT installation failed!"
    exit 1
fi
