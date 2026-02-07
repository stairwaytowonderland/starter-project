#!/bin/sh

set -e

healthcheck="/.healthcheck"

cleanup() {
    code=${1:-$?}
    # shellcheck disable=SC2015
    [ "$code" -eq 0 ] \
        && $LOGGER "** Exiting cleanly. Bye!" \
        || LEVEL='!' $LOGGER "Exiting with code ${code}. Bye!"
}

handle_int() {
    code=$?
    $LOGGER "** Detected interrupt (${code}). Cleanup..."
    trap - EXIT
    cleanup $code
    exit
}

trap handle_int INT
trap cleanup EXIT

out="/dev/null"
case "$1" in
    -i | --interactive)
        out="/dev/stdout"
        ;;
    *) ;;
esac

handle_watch() {
    watch -n 5 -e "[ '$(cat "$healthcheck")x' != 'x' ] && cat $healthcheck || false" > "$out" 2>&1 \
        || handle_int
}

handle_eof() {
    # shellcheck disable=SC2016
    [ "$out" != "/dev/null" ] || LEVEL='**' $LOGGER 'EXIT_ON_EOF is set to true. Press `CTRL+D` to exit.'
    # Run handle_watch in the background
    handle_watch &
    # Blocks until Ctrl+D (EOF)
    cat > /dev/null || true
    # Terminate the background handle_watch
    kill %1 2> /dev/null || true
}

if [ "${EXIT_ON_EOF:-false}" != "true" ]; then
    handle_watch
else
    handle_eof
fi
