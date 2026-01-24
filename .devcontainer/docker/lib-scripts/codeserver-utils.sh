#!/bin/sh

set -e

LEVEL='*' $LOGGER "Setting up code-server environment..."

sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/start-code-server \
    && sed -i "s|\$PASSGEN|$PASSGEN|g" /usr/local/bin/start-code-server \
    && sed -i "s|\$DEV|$DEV|g" /usr/local/bin/start-code-server

apt-get update \
    && apt-get -y install --no-install-recommends tini

$LOGGER "Done! code-server environment setup complete."
