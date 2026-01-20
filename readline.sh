#!/bin/sh
exec 3<&0
[ $# -eq 0 ] && set -- -
for f; do
    { { [ "$f" = - ] && exec <&3; } || exec < "$f"; } &&
    while IFS= read -r line; do
        printf '%s\n' "$line"
    done
done
