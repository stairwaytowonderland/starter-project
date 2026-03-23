#!/bin/sh

# Get the path to pipx binary

if type pipx > /dev/null 2>&1; then
    _pipx="$(which pipx)"
elif type "$(dirname "$BREW")/pipx" > /dev/null 2>&1; then
    _pipx="$(dirname "$BREW")/pipx"
else
    _pipx=""
fi

if [ -z "$_pipx" ]; then
    echo "pipx not found" >&2
    exit 1
fi

if [ "$#" -gt 0 ]; then
    "$_pipx" "$@"
else
    printf "%s\n" "$_pipx"
fi
