#!/bin/sh

set -eu

# Fix PATH to use the PATH variable from /etc/environment

# Usage: $FIXPATH [term]
#
# Arguments:
#   term: Term to search for in PATH (default: /usr/local/sbin)
#        Expected to be the first common entry in the
#        /etc/environment PATH and exported PATH. Typically
#        the first entry in PATH, and usually /usr/local/sbin
#        for Debian-based systems.
#
# Output:
#   Fixed PATH string

term=${1:-/usr/local/sbin}
search=$(echo "${2:-$PATH}" | awk -F"${term}:" '{print $2}')
replace=$(sed -nE '1s|^PATH=\"(.*)\"|\1|p' /etc/environment 2> /dev/null)

if ! echo "$PATH" | grep -q "$replace"; then
    replaced=$(echo "$PATH" | sed "s|$search|$replace|g" 2> /dev/null)
    PATH=$(echo "$replaced" | sed "s|${term}:||" 2> /dev/null)
fi

# Remove duplicate entries from PATH
# https://unix.stackexchange.com/questions/40749/remove-duplicate-path-entries-with-awk-command
if [ -n "$PATH" ]; then
    __path=$PATH:
    path=
    while [ -n "$__path" ]; do
        x=${__path%%:*}   # the first remaining entry
        case $path: in
            *:"$x":*) ;;    # already there
            *) path=$path:$x ;; # not there yet
        esac
        __path=${__path#*:}
    done
    PATH=${path#:}
    unset __path x
fi

printf "%s" "$PATH"
