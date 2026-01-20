#!/bin/sh
# shellcheck disable=SC2174

set -e

export DEBIAN_FRONTEND=noninteractive

if [ "$(uname -m)" = "x86_64" ]; then
    # Install AWS CLI v2 for x86_64
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
else
    # uname -m must be aarch64
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
fi
unzip -o awscliv2.zip
./aws/install --update
rm -rf ./aws
rm -f awscliv2.zip

# Enable AWS CLI bash completion for the non-root user
cat >> "/home/$USERNAME/.bashrc" << EOF

# Enable AWS CLI bash completion
if type aws_completer &>/dev/null
then
  complete -C aws_completer aws
elif type /usr/local/bin/aws_completer &>/dev/null; then
  complete -C "/usr/local/bin/aws_completer" aws
elif type /opt/homebrew/bin/aws_completer &>/dev/null; then
  complete -C "/opt/homebrew/bin/aws_completer" aws
fi
EOF

wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor \
    | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
    && gpg --no-default-keyring \
        --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
        --fingerprint \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \
  $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends terraform \
    && echo >> "/home/$USERNAME/.bashrc" \
    && echo 'complete -C /usr/bin/terraform terraform' >> "/home/$USERNAME/.bashrc"
