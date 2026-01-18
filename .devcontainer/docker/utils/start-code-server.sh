#!/bin/sh

BIND_ADDR="${BIND_ADDR:-0.0.0.0:8080}"
CODESERVER="/home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server"

[ "$DEBUG" != "true" ] || exec /bin/bash

if ! type "$CODESERVER" > /dev/null 2>&1; then
    LEVEL=error $LOGGER "Error: code-server not found at expected location: $CODESERVER" >&2
    exit 1
fi

if [ "${DEV:-$DEV}" = "true" ]; then
    $LOGGER "Running in DEV mode: disabling authentication for code-server"
    auth="none"
else
    $LOGGER "Set DEV=true to disable authentication for code-server"
    auth="password"
    export PASSWORD="${PASSWORD:-$($PASSGEN simple "$DEFAULT_PASS_LENGTH" "$DEFAULT_PASS_CHARSET")}"
fi

config_dir="$(dirname "$CODE_SERVER_CONFIG")"
extensions_dir="$(dirname "$CODE_SERVER_EXTENSIONS")"
[ -d "$config_dir" ] \
    || mkdir -p "$config_dir"
[ -d "$extensions_dir" ] \
    || mkdir -p "$extensions_dir"

if [ -f "$CODE_SERVER_EXTENSIONS" ]; then
    $LOGGER "Installing extensions from $CODE_SERVER_EXTENSIONS"
    extension_ids=$(jq -r '.[].identifier.id' "$CODE_SERVER_EXTENSIONS")
else
    $LOGGER "Installing extensions from $CODE_SERVER_WORKSPACE/.vscode/extensions.json"
    # Use cpp preprocessor to strip comments in JSON
    # extension_ids=$(cpp -P -E "$CODE_SERVER_WORKSPACE/.devcontainer/devcontainer.json" \
    # 	| jq -r '.customizations.vscode.extensions[]')
    extension_ids=$(cpp -P -E "$CODE_SERVER_WORKSPACE/.vscode/extensions.json" | jq -r '.recommendations[]')
fi
for extension_id in $extension_ids; do
    $LOGGER "Installing extension: $extension_id"
    $CODESERVER \
        --install-extension "$extension_id" \
        --extensions-dir "$extensions_dir"
done

# File is either 'sourced', or no arguments passed, so set default parameters
[ -n "$0" ] && [ -n "$1" ] \
    || set -- \
        --bind-addr "$BIND_ADDR" \
        --auth "$auth" \
        --cert false \
        "$CODE_SERVER_WORKSPACE"

# Ensure all parameters are set
config_only=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --config-only)
            shift
            config_only=true
            break
            ;;
        --bind-addr)
            bind_addr="${2-}"
            shift 2
            ;;
        --auth)
            auth="${2-}"
            shift 2
            ;;
        --cert)
            cert="${2-}"
            shift 2
            ;;
        --)
            break
            ;;
        *)
            break
            ;;
    esac
done

# Create config file to prevent one from being auto-generated
# with incorrect values (since parameters are passed on CLI)
cat > "$CODE_SERVER_CONFIG" << EOT
bind-addr: ${bind_addr:-$BIND_ADDR}
auth: ${auth:-password}
password: ${PASSWORD:-password}
cert: ${cert:-false}
EOT

if [ "$config_only" != "true" ]; then
    if [ -n "${1-}" ]; then
        $LOGGER "Starting code-server with workspace: ${1}"
    else
        $LOGGER "Starting code-server without a workspace"
    fi

    workspace_dir="${CODE_SERVER_WORKSPACE:-.}"
    [ -d "$workspace_dir" ] \
        || mkdir -p "$workspace_dir"

    # Start code-server with the specified parameters
    set -x
    exec $CODESERVER \
        --bind-addr "$bind_addr" --auth "$auth" --cert "$cert" \
        --extensions-dir "$extensions_dir" \
        "${@:-$workspace_dir}"
fi
