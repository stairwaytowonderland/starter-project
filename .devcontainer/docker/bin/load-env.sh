#!/usr/bin/env bash
# shellcheck disable=SC1091

__load_env() {
    local env_file="${1}"

    if [ -f "${env_file}" ] && [ -r "${env_file}" ]; then
        set -a
        # shellcheck disable=SC1090
        . "${env_file}"
        set +a
        echo "(*) Loaded environment variables from '${env_file}'" >&2
    else
        echo "(!) Warning: Environment file '${env_file}' not found or not readable." >&2
    fi
}

load_env() {
    # Declare script path variables in local scope since this is called from other scripts
    # ---------------------------------------
    if [ -z "$0" ]; then
        echo "(!) Cannot determine script path" >&2
        exit 1
    fi

    local script_name="$0"
    local script_dir
    script_dir="$(cd "$(dirname "$script_name")" && pwd)"
    # ---------------------------------------

    local default_env_file="${script_dir}/../.env"
    local from_script="${1:-false}"

    if [ -d "${1-}" ]; then
        echo "(+) Found .env file in directory '${1}'" >&2
        env_file="${1}/.env"
    else
        echo "(+) Using default .env file path '${default_env_file}'" >&2
        if [ "$from_script" = "true" ]; then
            env_file="$default_env_file"
        fi
    fi

    __load_env "$env_file"
}

load_env "$@"
