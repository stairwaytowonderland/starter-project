#!/bin/sh

set -e

$LOGGER "Setting up code-server environment..."

sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/start-code-server \
    && sed -i "s|\$PASSGEN|$PASSGEN|g" /usr/local/bin/start-code-server \
    && sed -i "s|\$DEV|$DEV|g" /usr/local/bin/start-code-server

apt-get update \
    && apt-get -y install --no-install-recommends tini

# Cleanup
apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

$LOGGER "Done! code-server environment setup complete."
