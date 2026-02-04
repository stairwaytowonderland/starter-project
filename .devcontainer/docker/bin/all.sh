#!/usr/bin/env bash
# shellcheck disable=SC1091

# ./.devcontainer/docker/bin/all.sh .

echo "(ƒ) Preparing to build and publish all Docker images..." >&2

# ---------------------------------------
set -euo pipefail

if [ -z "$0" ]; then
    echo "(!) Cannot determine script path" >&2
    exit 1
fi

script_name="$0"
script_dir="$(cd "$(dirname "$script_name")" && pwd)"
# ---------------------------------------

# Specify last argument as context if it's a directory
last_arg="${*: -1}"

. "${script_dir}/loader.sh" "${script_dir}/.."

# ---------------------------------------

if [ -d "$last_arg" ]; then
    BUILD_CONTEXT="$last_arg"
else
    BUILD_CONTEXT="${BUILD_CONTEXT:-"${script_dir}/../../.."}"
fi
if [ ! -d "$BUILD_CONTEXT" ]; then
    echo "(!) Docker context directory not found at expected path: ${BUILD_CONTEXT}" >&2
    exit 1
fi

REMOTE_USER="${REMOTE_USER:-vscode}"

CODESERVER_BIND_ADDR=$(
    CODESERVER_BIND_ADDR="${CODESERVER_BIND_ADDR:-0.0.0.0:13337}"
    CODESERVER_CONTAINER_PORT="${CODESERVER_CONTAINER_PORT:-${CODESERVER_BIND_ADDR##*:}}"
    CODESERVER_HOST_IP="${CODESERVER_HOST_IP:-${CODESERVER_BIND_ADDR%%:*}}"
    printf "%s:%s" "${CODESERVER_HOST_IP}" "${CODESERVER_CONTAINER_PORT}"
)

REPO_NAME="${REPO_NAME-}"
REPO_NAMESPACE="${REPO_NAMESPACE-}"
bin_dir=".devcontainer/docker/bin"

if ! . "${script_dir}/login.sh" "$REPO_NAMESPACE" "$REPO_NAME"; then
    echo "Error: Not logged in to ${REGISTRY_PROVIDER} Container Registry." >&2
    exit 1
fi

main() {
    # Newline-separated list of commands to run
    local all_commands=""
    while IFS= read -r cmd || [ -n "$cmd" ]; do
        [ -n "$cmd" ] || continue
        [ -n "$all_commands" ] \
            && all_commands="$all_commands && $cmd" \
            || all_commands="$cmd"
    done << EOF
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:filez $REMOTE_USER $* $BUILD_CONTEXT
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:builder $REMOTE_USER $* $BUILD_CONTEXT
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME $REMOTE_USER --build-arg PYTHON_VERSION=devcontainer --build-arg PRE_COMMIT_ENABLED=true $* $BUILD_CONTEXT
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:devtools $REMOTE_USER --build-arg DEV_PARENT_IMAGE=brewuser --build-arg PYTHON_VERSION=latest $* $BUILD_CONTEXT
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:cloudtools $REMOTE_USER --build-arg PYTHON_VERSION=devcontainer $* $BUILD_CONTEXT
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:codeserver $REMOTE_USER --build-arg BIND_ADDR=$CODESERVER_BIND_ADDR --build-arg PYTHON_VERSION=latest --build-arg DEFAULT_PASS_CHARSET='a-zA-Z0-9' $* $BUILD_CONTEXT
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/build.sh $REPO_NAME:codeserver-minimal $REMOTE_USER --build-arg BIND_ADDR=$CODESERVER_BIND_ADDR --build-arg PYTHON_VERSION=system --build-arg DEFAULT_PASS_CHARSET='a-zA-Z0-9' $* $BUILD_CONTEXT
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:codeserver-minimal $REPO_NAMESPACE
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:codeserver $REPO_NAMESPACE
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:cloudtools $REPO_NAMESPACE
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:devtools $REPO_NAMESPACE
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:builder $REPO_NAMESPACE
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME:filez $REPO_NAMESPACE
TIME_MSG_LABEL= TIME_MSG_PREFIX= $BUILD_CONTEXT/$bin_dir/publish.sh $REPO_NAME $REPO_NAMESPACE
EOF

    "${script_dir}/executer.sh" sh -c "$all_commands"
}

for arg in "$@"; do
    if [ "$arg" != "$BUILD_CONTEXT" ]; then
        com+=("$arg")
    fi
done

TIME_MSG_LABEL="==> " TIME_MSG_PREFIX="TOTAL time" main "${com[@]}"

echo "(√) Done! All Docker images built and published." >&2
# echo "_______________________________________" >&2
echo >&2
