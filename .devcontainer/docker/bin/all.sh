#!/usr/bin/env bash
# shellcheck disable=SC1091

# ./.devcontainer/docker/bin/all.sh .

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ]; then
    echo "Cannot determine script path"
    exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# Specify last argument as context if it's a directory
last_arg="${*: -1}"

. "$script_dir/load-env.sh" "$script_dir/.."

if [ -d "$last_arg" ]; then
    BUILD_CONTEXT="$last_arg"
else
    BUILD_CONTEXT="${BUILD_CONTEXT:-"$script_dir/../../.."}"
fi
if [ ! -d "$BUILD_CONTEXT" ]; then
    echo "Docker context directory not found at expected path: $BUILD_CONTEXT"
    exit 1
fi

REMOTE_USER="${REMOTE_USER:-vscode}"

REPO_NAME="${REPO_NAME-}"
REPO_NAMESPACE="${REPO_NAMESPACE-}"
bin_dir=".devcontainer/docker/bin"

main() {
    # Newline-separated list of commands to run
    local all_commands=""
    while IFS= read -r cmd || [ -n "$cmd" ]; do
        [ -n "$cmd" ] || continue
        [ -n "$all_commands" ] \
            && all_commands="$all_commands && $cmd" \
            || all_commands="$cmd"
    done << EOF
$BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:builder $REMOTE_USER "$@" $BUILD_CONTEXT
$BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME $REMOTE_USER --build-arg PYTHON_VERSION=devcontainer --build-arg PRE_COMMIT_ENABLED=true "$@" $BUILD_CONTEXT
$BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:devtools $REMOTE_USER --build-arg DEV_PARENT_IMAGE=brewuser --build-arg PYTHON_VERSION=latest "$@" $BUILD_CONTEXT
$BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:cloudtools $REMOTE_USER --build-arg PYTHON_VERSION=devcontainer "$@" $BUILD_CONTEXT
$BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:codeserver $REMOTE_USER --build-arg BIND_ADDR=$CODESERVER_BIND_ADDR --build-arg PYTHON_VERSION=latest --build-arg DEFAULT_PASS_CHARSET='a-zA-Z0-9' "$@" $BUILD_CONTEXT
$BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:codeserver-minimal $REMOTE_USER --build-arg BIND_ADDR=$CODESERVER_BIND_ADDR --build-arg PYTHON_VERSION=system --build-arg DEFAULT_PASS_CHARSET='a-zA-Z0-9' "$@" $BUILD_CONTEXT
$BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:codeserver-minimal $REPO_NAMESPACE
$BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:codeserver $REPO_NAMESPACE
$BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:cloudtools $REPO_NAMESPACE
$BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:devtools $REPO_NAMESPACE
$BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:builder $REPO_NAMESPACE
$BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME $REPO_NAMESPACE
EOF

    "$script_dir/exec-com.sh" sh -c "$all_commands"
}

for arg in "$@"; do
    if [ "$arg" != "$BUILD_CONTEXT" ]; then
        com+=("$arg")
    fi
done

main "${com[@]}"
