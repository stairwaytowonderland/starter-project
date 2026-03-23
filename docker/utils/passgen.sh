#!/bin/sh

set -e

# Generate a random $DEFAULT_PASS_LENGTH-character alphanumeric password (unless otherwise specified)

# Usage: $PASSGEN [-<n>] [mode] [modifier] [length] [charset|min_char_per_fam]
#
# Arguments:
#   n: (quantity) Number of passwords to generate (default: 0; max: $DEFAULT_MAX_QTY)
#       n=0 (default) - Generates a single password without line breaks.
#       n>0,n<=$DEFAULT_MAX_QTY - generates quantity n passwords, one per line.
#   mode: '-s|--simple' for simple password generation (default)
#         '-r|--requirements' for password generation with character family requirements
#   modifier: '-B|--no-ambiguous' to exclude ambiguous characters (e.g., l, i, j, o, O, 0, s, S, 5, z, Z, 2)
#             '-V|--no-vowels' to exclude vowels (e.g., a, e, i, o, u) to prevent accidental profanity
#             '-X|--remove <chars>' to specify additional characters to remove from the character set (e.g., -X '!@#')
#   length: Length of password to generate (default: $DEFAULT_PASS_LENGTH)
#   charset: Characters to use for password generation (simple mode only; default: $DEFAULT_PASS_CHARSET)
#           Use '[:graph:]' for all printable characters (except space)
#           Use '[:alnum:]' for alphanumeric characters plus digits
#           Use a custom set of characters (e.g. '0-9a-zA-Z!@#$%^&*()')
#   min_char_per_fam: Minimum characters per family (requirements mode only; default: 2)
#
# Positional args can be used as an alternative to options:
#   length: Length of password to generate
#   charset|min_char_per_fam: Charset for simple mode or min chars for requirements mode
#
# Examples:
#   $PASSGEN 64
#   $PASSGEN -5 20
#   $PASSGEN 20 '0-9a-zA-Z!@#$%^&*()'
#   $PASSGEN -r -l 16
#   $PASSGEN -s -l 32 -c 'a-zA-Z0-9!@#$%^&*()'
#   $PASSGEN -5 -r -l 20
#   $PASSGEN -B -V
#   $PASSGEN --simple 12 'a-zA-Z0-9'
#   $PASSGEN --requirements 16 3
#   $PASSGEN -10 --requirements -B -V -X 'jvV!@#' 24 4
#
# Output:
#   Randomly generated password

# Redundant checker for default values to ensure they are set even if not passed as build args
DEFAULT_PASS_LENGTH="${DEFAULT_PASS_LENGTH:-32}"
DEFAULT_PASS_CHARSET="${DEFAULT_PASS_CHARSET:-[:graph:]}"

DEFAULT_PASS_LENGTH="${DEFAULT_PASS_LENGTH:-$DEFAULT_PASS_LENGTH}"
DEFAULT_PASS_CHARSET="${DEFAULT_PASS_CHARSET:-$DEFAULT_PASS_CHARSET}"
DEFAULT_MAX_QTY="${DEFAULT_MAX_QTY:-10000}"
DEFAULT_MIN_CHAR_PER_FAM="${DEFAULT_MIN_CHAR_PER_FAM:-2}"

_pg_gnu_compat() {
    # Check for GNU coreutils compatibility
    type "$1" > /dev/null 2>&1 && "$1" --version > /dev/null 2>&1 && "$1" --version | grep -iqE "^.*\(gnu coreutils).*$"
}

# shellcheck disable=SC2015
_pg_head() { _pg_gnu_compat head && head "$@" || { _pg_gnu_compat ghead "$@" && ghead "$@"; }; }
# shellcheck disable=SC2015
_pg_fold() { _pg_gnu_compat fold && fold "$@" || { _pg_gnu_compat gfold "$@" && gfold "$@"; }; }
# shellcheck disable=SC2015
_pg_shuf() { _pg_gnu_compat shuf && shuf || { _pg_gnu_compat gshuf && gshuf; }; }
# shellcheck disable=SC2015
_pg_tr() { _pg_gnu_compat tr && tr "$@" || { _pg_gnu_compat gtr && gtr "$@"; }; }

pg_default_charset() {
    full_charset='[:graph:]'

    # alpha_charset='[:alnum:]'
    # custom_charset='0-9a-zA-Z!%^&.@\$*_:.,?-'
    echo "${DEFAULT_PASS_CHARSET:-$full_charset}"
}

pg_printablechars() {
    # Print all printable ASCII characters (decimal 32 to 126)
    for i in $(seq 32 126); do
        OCTAL=$(printf '\\%o' "$i")
        printf "%b" "$OCTAL"
    done
}

# ! This function causes significant performance degradation; Use only if modifier flags are set.
pg_normalize_charset() {
    # Convert character set to tr-compatible format
    charset="$1"
    noambiguous="${noambiguous:-false}"
    novowels="${novowels:-false}"
    remove="${remove:-}"

    if $noambiguous || $novowels || [ -n "$remove" ]; then
        case "$charset" in
            *[:'*':]*)
                # Assume POSIX character class (e.g., [:graph:])
                charset="$(pg_printablechars | tr -dc "$charset")"
                ;;
        esac

        ! $noambiguous || remove='lijoO0sS5zZ2'"$remove"
        ! $novowels || remove='aeiouAEIOU'"$remove"

        # shellcheck disable=SC2016
        [ -z "$remove" ] || charset="$(echo "$charset" | tr -d "$remove" | sed 's/[][\.*^$(){}?+|/]/\\&/g')"
    fi

    echo "$charset"
}

pg_simple_pass() {
    charset="$(pg_normalize_charset "${2:-$(pg_default_charset)}")"
    LC_ALL=C tr -dc "$charset" < /dev/urandom | head -c "${1:-$DEFAULT_PASS_LENGTH}" || pg_usage $?
}

pg_requirements_pass() {
    # Guarantees at least 2 characters from each character family: digits, lowercase, uppercase, special

    max_string_len=${1:-$DEFAULT_PASS_LENGTH}
    min_char_per_fam=${2:-$DEFAULT_MIN_CHAR_PER_FAM}

    tr_num=$(pg_normalize_charset '[:digit:]')
    tr_lower=$(pg_normalize_charset '[:lower:]')
    tr_upper=$(pg_normalize_charset '[:upper:]')
    tr_grammar=$(pg_normalize_charset '!~:.,;?-_')
    tr_symbols=$(pg_normalize_charset '#%^&@\$*+=')
    tr_brackets=$(pg_normalize_charset '|<>[]\{\}()\/')

    set -- "$tr_num" "$tr_lower" "$tr_upper" "$tr_grammar" "$tr_symbols" "$tr_brackets"
    count="$#"
    shift $count

    remaining_chars="$((max_string_len - count * min_char_per_fam))"

    [ $remaining_chars -ge 0 ] || remaining_chars=0

    (
        LC_ALL=C tr -dc "${tr_num}"     < /dev/urandom | _pg_head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_lower}"   < /dev/urandom | _pg_head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_upper}"   < /dev/urandom | _pg_head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_grammar}"   < /dev/urandom | _pg_head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_symbols}" < /dev/urandom | _pg_head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_brackets}" < /dev/urandom | _pg_head -c "${min_char_per_fam}"
        LC_ALL=C tr -dc "${tr_num}${tr_lower}${tr_upper}${tr_grammar}${tr_symbols}${tr_brackets}" < /dev/urandom | _pg_head -c "${remaining_chars}"
    ) | _pg_fold -w1 | _pg_shuf | _pg_tr -d '\n' || pg_usage $?
}

pg_usage() {
    code="${1:-0}"
    C_BOLD=${C_BOLD:-$(printf '\033[1m')}
    C_DEFAULT=${C_DEFAULT:-$(printf '\033[0m')}
    cat << EOT >&2
${C_BOLD}USAGE${C_DEFAULT}
    $PASSGEN [-<n>] [mode] [modifier] [options] [pg_positional_args]

${C_BOLD}ARGUMENTS${C_DEFAULT}
    quantity (optional):
        n: Number of passwords to generate (default: 0; max: $DEFAULT_MAX_QTY)
            n=0 (default) - Generates a single password without line breaks.
            n>0,n<=$DEFAULT_MAX_QTY - generates quantity n passwords, one per line.

    mode (optional):
        '-s|--simple' for simple password generation (default)
        '-r|--requirements' for password generation with character family requirements
            !! Pre-requisites:
            ==================
            The --requirements mode requires minimum length of at least 12 characters
            to ensure it can meet the character family requirements.
            The --requirements mode requires GNU coreutils for the
            shuf, head, fold, and tr utilities.

    modifier (optional):
        '-B|--no-ambiguous' to exclude ambiguous characters (e.g., l, i, j, o, O, 0, s, S, 5, z, Z, 2)
        '-V|--no-vowels' to exclude vowels (e.g., a, e, i, o, u) to prevent accidental profanity
        '-X|--remove <chars>' to specify additional characters to remove from the character set (e.g., -X '!@#')

    options (must be used with mode):
        -l, --length <n>                Password length (default: $DEFAULT_PASS_LENGTH)
        -c, --charset <chars>           Character set for simple mode;
                                        not valid with requirements mode (default: $DEFAULT_PASS_CHARSET)
        -m, --min-char-per-fam <n>      Minimum characters per family for requirements mode;
                                        not valid with simple mode (default: 2)

    Positional args (optional; alternative to options):
        length: Length of password to generate
        charset|min_char_per_fam: Charset for simple mode or min chars for requirements mode

${C_BOLD}EXAMPLES${C_DEFAULT}
    $PASSGEN 64
    $PASSGEN -5 20
    $PASSGEN 20 '0-9a-zA-Z!@#\$%^&*()'
    $PASSGEN -r -l 16
    $PASSGEN -s -l 32 -c 'a-zA-Z0-9!@#\$%^&*()'
    $PASSGEN -5 -r -l 20
    $PASSGEN -B -V
    $PASSGEN --simple 12 'a-zA-Z0-9'
    $PASSGEN --requirements 16 3
    $PASSGEN -10 --requirements -B -V -X 'jvV!@#' 24 4
EOT
    exit "$code"
}

pg_positional_args() {
    if echo "$1" | grep -qE "^[0-9]+$"; then
        # Check if there are flag-based options after positional argument
        [ "$#" -eq 0 ] || echo "$2" | grep -qvE "^-" || pg_usage 1
        echo "$1"
    fi
}

pg_parse_args() {
    mode='simple' noambiguous=false novowels=false remove=''
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -B | --ambiguous)
                noambiguous=true
                shift
                ;;
            -h | --help)
                pg_usage 0
                ;;
            -r | --requirements)
                mode='requirements'
                shift
                ;;
            -s | --simple)
                mode='simple'
                shift
                ;;
            -V | --no-vowels)
                novowels=true
                shift
                ;;
            -X | --exclude)
                remove="${remove}${2}"
                shift 2
                ;;
            -*) pg_usage 1 ;;
            *) break ;;
        esac
    done

    if [ "$mode" = "simple" ]; then
        positional_length=$(pg_positional_args "$@")
        if [ -n "$positional_length" ]; then
            shift
            charset="${1:-$(pg_default_charset)}"
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
                        pg_usage 1
                        ;;
                    *) break ;;
                esac
            done
        fi
        pg_simple_pass "${length:-$positional_length}" "${charset:-$(pg_default_charset)}"
        return $?
    elif [ "$mode" = "requirements" ]; then
        positional_length=$(pg_positional_args "$@")
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
                        pg_usage 1
                        ;;
                    *) break ;;
                esac
            done
        fi
        pg_requirements_pass "${length:-$positional_length}" "${min_char:-$DEFAULT_MIN_CHAR_PER_FAM}"
        return $?
    fi
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
            printf "%s\n" "$(pg_parse_args "$@")"
            count=$((count + 1))
        done
    else
        pg_parse_args "$@"
    fi
}

passgen "$@"
