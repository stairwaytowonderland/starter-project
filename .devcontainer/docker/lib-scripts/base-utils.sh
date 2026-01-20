#!/bin/sh

set -e

$LOGGER "Installing base utilities and dependencies..."

apt-get update

export DEBIAN_FRONTEND=noninteractive

apt-get -y install --no-install-recommends \
    shfmt \
    openssh-client

# [ -d /etc/apt/keyrings ] || mkdir -p -m 755 /etc/apt/keyrings \
#     && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
#     && cat "$out" | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
#     && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
#     && mkdir -p -m 755 /etc/apt/sources.list.d \
#     && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
#     && apt-get update \
#     && apt-get -y install --no-install-recommends gh \
#     && echo >> "/home/$USERNAME/.bashrc" \
#     && echo 'eval "$(gh completion -s bash)"' >> "/home/$USERNAME/.bashrc" \
#     && rm -f "$out"

$LOGGER "Done! Base utilities installation complete."
