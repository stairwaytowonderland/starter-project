#!/bin/sh

set -e

# Generate a random $DEFAULT_PASS_LENGTH-character alphanumeric password (unless otherwise specified)

# Usage: $PASSGEN [simple|requirements] [length] [charset|min_char_per_fam]
#
# Arguments:
#   mode: 'simple' for simple password generation (default)
#         'requirements' for password generation with character family requirements
#   length: Length of password to generate (default: $DEFAULT_PASS_LENGTH)
#   charset: Characters to use for password generation (simple mode only; default: $DEFAULT_PASS_CHARSET)
#           Use '[:graph:]' for all printable characters (except space)
#           Use '[:alnum:]' for alphanumeric characters plus digits
#           Use a custom set of characters (e.g. '0-9a-zA-Z!@#$%^&*()')
#   min_char_per_fam: Minimum characters per family (requirements mode only; default: 2)
#
# Output:
#   Randomly generated password

_DEFAULT_PASS_LENGTH="${DEFAULT_PASS_LENGTH:-32}"
_DEFAULT_PASS_CHARSET="${DEFAULT_PASS_CHARSET:-[:graph:]}"

DEFAULT_PASS_LENGTH="${DEFAULT_PASS_LENGTH:-$_DEFAULT_PASS_LENGTH}"
DEFAULT_PASS_CHARSET="${DEFAULT_PASS_CHARSET:-$_DEFAULT_PASS_CHARSET}"
DEFAULT_MAX_QTY="${DEFAULT_MAX_QTY:-10000}"
DEFAULT_MIN_CHAR_PER_FAM="${DEFAULT_MIN_CHAR_PER_FAM:-2}"

gnu_compat() {
    # Check for GNU coreutils compatibility
    type "$1" > /dev/null 2>&1 && "$1" --version > /dev/null 2>&1 && "$1" --version | grep -iqE "^.*\(gnu coreutils).*$"
}

# shellcheck disable=SC2015
_head() { gnu_compat head && head "$@" || { gnu_compat ghead "$@" && ghead "$@"; }; }
# shellcheck disable=SC2015
_fold() { gnu_compat fold && fold "$@" || { gnu_compat gfold "$@" && gfold "$@"; }; }
# shellcheck disable=SC2015
_shuf() { gnu_compat shuf && shuf || { gnu_compat gshuf && gshuf; }; }
# shellcheck disable=SC2015
_tr() { gnu_compat tr && tr "$@" || { gnu_compat gtr && gtr "$@"; }; }

default_charset() {
    full_charset='[:graph:]'
    # alpha_charset='[:alnum:]'
    # custom_charset='0-9a-zA-Z!%^&.@\$*_:.,?-'
    echo "${DEFAULT_PASS_CHARSET:-$full_charset}"
}

simple_pass() {
    # Does not guarantee character family requirements
    LC_ALL=C tr -dc "${2:-$(default_charset)}" < /dev/urandom | head -c"${1:-$DEFAULT_PASS_LENGTH}" || usage $?
}

requirements_pass() {
    # Guarantees at least 2 characters from each character family: digits, lowercase, uppercase, special

    max_string_len=${1:-$DEFAULT_PASS_LENGTH}
    min_char_per_fam=${2:-$DEFAULT_MIN_CHAR_PER_FAM}

    tr_num='0-9'
    tr_lower='a-z'
    tr_upper='A-Z'
    tr_special='!%^&.@\$*_:.,?-'
    tr_special_addtl='~#|<>[]\{\}()\/+=;'

    set -- "$tr_num" "$tr_lower" "$tr_upper" "$tr_special" "$tr_special_addtl"
    count="$#"
    shift $count

    remaining_chars="$((max_string_len - count * min_char_per_fam))"

    [ $remaining_chars -ge 0 ] || remaining_chars=0

    (
        LC_ALL=C tr -dc "${tr_num}"     < /dev/urandom | _head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_lower}"   < /dev/urandom | _head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_upper}"   < /dev/urandom | _head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_special}" < /dev/urandom | _head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_special_addtl}" < /dev/urandom | _head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_num}${tr_lower}${tr_upper}${tr_special}${tr_special_addtl}" < /dev/urandom | _head -c "${remaining_chars}"
    ) | _fold -w1 | _shuf | _tr -d '\n' || usage $?
}

usage() {
    code="${1:-0}"
    cat << EOT >&2
Usage: $PASSGEN [-quantity] [mode] [options] [positional_args]
Arguments:
  quantity: Number of passwords to generate (default: 1; max: 99)
  mode: '-s|--simple' for simple password generation (default)
        '-r|--requirements' for password generation with character family requirements
          !! Pre-requisites:
            - The --requirements mode requires minimum length of at least 10 characters
              to ensure it can meet the character family requirements.
            - The --requirements mode requires GNU coreutils for the shuf, head, fold, and tr utilities.

Options (must be used with modes):
  -l, --length <n>              Password length (default: $DEFAULT_PASS_LENGTH)
  -c, --charset <chars>         Character set for simple mode
  -m, --min-char-per-fam <n>    Minimum characters per family for requirements mode (default: 2)

Positional args (alternative to options):
  length: Length of password to generate
  charset|min_char_per_fam: Charset for simple mode or min chars for requirements mode

Examples:
  $PASSGEN 64
  $PASSGEN -5 20
  $PASSGEN 20 '0-9a-zA-Z!@#\$%^&*()'
  $PASSGEN -r -l 16
  $PASSGEN -s -l 32 -c 'a-zA-Z0-9!@#\$%^&*()'
  $PASSGEN -5 -r -l 20
  $PASSGEN --simple 12 'a-zA-Z0-9'
  $PASSGEN --requirements 16 3
EOT
    exit "$code"
}

positional_args() {
    if echo "$1" | grep -qE "^[0-9]+$"; then
        # Check if there are flag-based options after positional argument
        [ "$#" -eq 0 ] || echo "$2" | grep -qvE "^-" || usage 1
        echo "$1"
    fi
}

parse_args() {
    case "$1" in
        -s | --simple)
            shift
            positional_length=$(positional_args "$@")
            if [ -n "$positional_length" ]; then
                shift
                charset="${1:-$(default_charset)}"
            else
                while [ "$#" -gt 0 ]; do
                    case "$1" in
                        -l | --length)
                            length="$2"
                            shift 2
                            ;;
                        -c | --charset)
                            charset="$2"
                            shift 2
                            ;;
                        -m | --min-char-per-fam)
                            LEVEL='error' $LOGGER "-m|--min-char-per-fam is not valid with -s|--simple mode"
                            usage 1
                            ;;
                        *) break ;;
                    esac
                done
            fi
            simple_pass "${length:-$positional_length}" "${charset:-$(default_charset)}"
            return $?
            ;;
        -r | --requirements)
            shift
            positional_length=$(positional_args "$@")
            if [ -n "$positional_length" ]; then
                shift
                min_char="${1:-$DEFAULT_MIN_CHAR_PER_FAM}"
            else
                while [ "$#" -gt 0 ]; do
                    case "$1" in
                        -l | --length)
                            length="$2"
                            shift 2
                            ;;
                        -m | --min-char-per-fam)
                            min_char="$2"
                            shift 2
                            ;;
                        -c | --charset)
                            LEVEL='error' $LOGGER "-c|--charset is not valid with -r|--requirements mode"
                            usage 1
                            ;;
                        *) break ;;
                    esac
                done
            fi
            requirements_pass "${length:-$positional_length}" "${min_char:-$DEFAULT_MIN_CHAR_PER_FAM}"
            return $?
            ;;
        -h | --help)
            usage 0
            ;;
        -*) usage 1 ;;
        *)
            simple_pass "$@"
            return $?
            ;;
    esac
}

passgen() {
    qty=0
    first_arg="${1-}"
    if echo "$first_arg" | grep -qE "^-[0-9]+$"; then
        qty="${first_arg#-}"
        shift
    fi
    if [ "$qty" -gt 0 ] && [ "$qty" -lt "$DEFAULT_MAX_QTY" ]; then
        count=0
        while [ $count -lt "$qty" ]; do
            printf "%s\n" "$(parse_args "$@")"
            count=$((count + 1))
        done
    else
        parse_args "$@"
    fi
}

passgen "$@"
