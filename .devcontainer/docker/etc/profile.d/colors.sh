#!/usr/bin/env bash

# Usage: bash /path/to/colors.sh [OPTIONS] [GRID_COLS]
#
#   OPTIONS:
#     -256, --extended:     Show the full 256-color palette and corresponding escape codes (default: unset);
#                           Omit for standard 8-bit ANSI color codes with brightness variants.
#     -b, --bgchar [CHAR]:  Character to use for background color demonstration in the color (palette) grid (default: '█')
#     -n, --same-line:      Print foreground-only colors on the same line (default: false)
#     -h, --help:           Show this help message and exit
#
#   GRID_COLS: Number of columns to display in the color grid (default: 8)
#
# Examples:
#   bash colors.sh
#   bash colors.sh -256
#   bash colors.sh -n
#   bash colors.sh -256 -n -b '██' 16
#   bash colors.sh 4

colorgrid256() {
    local cols="${1:-8}" bgchar="${2:-█}" i
    ((cols > 0)) || return $?
    for i in {0..255}; do
        printf "\e[38;5;%sm%s %03d " "$i" "$bgchar" "$i"
        if (((i + 1) % cols == 0)); then
            printf "\n"
        fi
    done
}

colorgrid8() {
    local isbright="${1:-false}" cols="${2:-8}" bgchar="${3:-█}" base i
    ((cols > 0)) || return $?
    $isbright && base=90 || base=30
    for i in {0..7}; do
        printf "\e[%sm%s %03d " "$((i + base))" "$bgchar" "$((i + base))"
        if (((i + 1) % cols == 0)); then
            printf "\n"
        fi
    done
}

colorgrid8_with_brightness() {
    local cols="${1:-8}" bgchar="${2-}" base bright i
    ((cols > 0)) || return $?
    [ -n "$bgchar" ] || bgchar="█"
    base=(30 90)
    for bright in "${base[@]}"; do
        for i in {0..7}; do
            printf "\e[%sm%s %03d " "$((bright + i))" "$bgchar" "$((bright + i))"
            if (((i + 1) % cols == 0)); then
                printf "\n"
            fi
        done
    done
}

colors256() {
    local sameline="${1:-false}" range=256 cols=8 colors bg fg
    # shellcheck disable=SC2207
    colors=($(seq 0 $((range - 1))))
    cols=$((cols % range))
    for bg in "${colors[@]}"; do
        for fg in "${colors[@]}"; do
            printf "\e[38;5;%03dm\e[48;5;%03dm"'\\e[38;5;'"%03d"m'\\e[48;5;'"%03d"m'\e[0m' "$fg" "$bg" "$fg" "$bg"
            [ "$sameline" != "true" ] || if (((fg + 1) % (cols / 2) == 0)); then
                printf "\e[38;5;%03dm"'\\e[38;5;'"%03d"m'\e[0m' "$fg" "$fg"
            fi
            if (((fg + 1) % (cols / 2) == 0)); then
                printf "\n"
            fi
        done
    done
    if [ "$sameline" != "true" ]; then
        for fg in "${colors[@]}"; do
            printf "\e[38;5;%03dm"'\\e[38;5;'"%03d"m'\e[0m' "$fg" "$fg"
            if (((fg + 1) % cols == 0)); then
                printf "\n"
            fi
        done
    fi
}

colors8() {
    local isbright="${1:-false}" sameline="${2:-false}" range=8 cols base colors bg fg
    $isbright && base=90 || base=30
    # shellcheck disable=SC2207
    colors=($(seq 0 $((range - 1))))
    cols="${#colors[@]}"
    for fg in "${colors[@]}"; do
        for bg in "${colors[@]}"; do
            printf "\e[%dm\e[%dm"'\\e['"%dm\\e['"%dm'\e[0m' "$((base + fg))" "$((base + bg + 10))" "$((base + fg))" "$((base + bg + 10))"
            [ "$sameline" != "true" ] || if (((bg + 1) % cols == 0)); then
                printf "\e[%dm"'\\e['"%d"m'\e[0m' "$((base + fg))" "$((base + fg))"
            fi
            if (((bg + 1) % cols == 0)); then
                printf "\n"
            fi
        done
    done
    if [ "$sameline" != "true" ]; then
        for fg in "${colors[@]}"; do
            printf "\e[%dm"'\\e['"%d"m'\e[0m' "$((base + fg))" "$((base + fg))"
            if (((fg + 1) % cols == 0)); then
                printf "\n"
            fi
        done
    fi
}

colors8_with_brightness() {
    local sameline="${1:-false}" range=8 cols base colors bg fg bright
    base=(30 90)
    # shellcheck disable=SC2207
    colors=($(seq 0 $((range - 1))))
    cols="${#colors[@]}"
    for bright in "${base[@]}"; do
        for fg in "${colors[@]}"; do
            for bg in "${colors[@]}"; do
                printf "\e[%dm\e[%dm"'\\e['"%dm\\e['"%dm'\e[0m' "$((bright + fg))" "$((bright + bg + 10))" "$((bright + fg))" "$((bright + bg + 10))"
                [ "$sameline" != "true" ] || if (((bg + 1) % cols == 0)); then
                    printf "\e[%dm"'\\e['"%d"m'\e[0m' "$((bright + fg))" "$((bright + fg))"
                fi
                if (((bg + 1) % cols == 0)); then
                    printf "\n"
                fi
            done
        done
    done
    if [ "$sameline" != "true" ]; then
        for bright in "${base[@]}"; do
            for fg in "${colors[@]}"; do
                printf "\e[%dm"'\\e['"%d"m'\e[0m' "$((bright + fg))" "$((bright + fg))"
                if (((fg + 1) % cols == 0)); then
                    printf "\n"
                fi
            done
        done
    fi
}

colorsusage() {
    local script_name='colors' exit="${1-}"
    [ "$0" != "${BASH_SOURCE[0]}" ] || script_name="${0##*/}"
    cat << EOF
Usage: $script_name [OPTION]... [GRID_COLS]
Description: Display colors with corresponding ANSI or EXTENDED escape codes,
             followed by a color palette grid.
Example: $script_name -256 -n -b '⬤ ' 16
GRID_COLS is the number of columns to display in the color grid (default: 8).

Palette:
  -256, --extended:     Show the full 256-color palette and corresponding
                        escape codes (default: unset); Omit for standard
                        8-bit ANSI color codes with brightness variants.
  -b, --bgchar [CHAR]:  Character(s) to use for background color demonstration
                        in the color (palette) grid (default: '█')

Formatting:
  -n, --same-line:      Print foreground-only colors on the same line (default: false)

Miscellaneous:
  -h, --help:           Show this help message and exit

Additional Examples:
\$ $script_name
\$ $script_name -256
\$ $script_name -n
\$ $script_name -256 -n -b '██' 16
\$ $script_name 4
EOF

    [ -z "$exit" ] || return "$exit"
}

colors() {
    local extended=false sameline=false _cols=8 cols bgchar _missing
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -256 | --extended)
                extended=true
                shift
                ;;
            -b | --bgchar)
                if [ -n "${2-}" ]; then
                    bgchar="$2"
                    shift 2
                else
                    _missing="$1"
                    shift
                    break
                fi
                ;;
            -n | --same-line)
                sameline=true
                shift
                ;;
            -h | --help)
                colorsusage
                return 0
                ;;
            *[!0-9]*)
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    if [ -n "${_missing-}" ]; then
        echo "Error: Missing argument for ${_missing}" >&2
        colorsusage 1
        # local _err=$?
        # [ "$_err" -eq 0 ] || return "$_err"
    else
        if [[ $1 =~ ^[0-9]+$ ]]; then
            cols="$1"
            shift
        else
            cols="$_cols"
        fi
        if $extended; then
            colors256 $sameline
            ! $sameline || echo
            colorgrid256 "$cols" "$bgchar"
        else
            colors8_with_brightness $sameline
            ! $sameline || echo
            colorgrid8_with_brightness "$cols" "$bgchar"
        fi
        [ "$cols" -le "$_cols" ] || echo
    fi
}

if [ "$0" = "${BASH_SOURCE[0]}" ]; then
    set -e
    colors "$@"
fi
